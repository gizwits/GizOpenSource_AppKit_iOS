#include <time.h>
#include <stdio.h>
#include <errno.h>
#include <netdb.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <sys/socket.h>
#include <netinet/tcp.h>

#include "ssl.h"
#include "err.h"
#include "rand.h"

typedef struct _sslConnection_st {
    int fd;
    SSL *handle;
    SSL_CTX *context;
} sslConnection_st;

#ifdef __cplusplus
extern "C" {
#endif

#include "GizLog.h"

#ifdef TARGET_OS_IPHONE
#import <Foundation/Foundation.h>
#endif

/*
 * 32 个字节的 ICMP 包，包含包头
 */
typedef struct _ICMPPHead_t {
    unsigned char type;
    unsigned char code;
    unsigned short crc;
    unsigned short id;
    unsigned short seq;
    unsigned long timestamp;
} ICMPPHead_t;

static GizLog_t gGizLog = { 3 };   //默认打印error+debug+data+busi
static char gTimeStr[32] = { 0 };  //时间格式化输出字符串
static char gSysInfoLogBuf[LOG_MAX_LEN] = { 0 }; //缓存系统信息，每创建一个新文件时存入文件首行供排查问题用
static char gInitedGizLogMutex = 0; //是否初始化过日志锁
static char gUploadedTheInitLog = 0; //是否上传过初始日志(程序启动前就已经存在的日志)
static pthread_mutex_t gMutexGizLog; //加锁防止多线程同时修改GizLog造成异常
static const char *gGizLogVersion = "2.1.0.16120219"; //GizWits日志版本号

static int setSockTime(int fd, int readSec, int writeSec)
{
    int iRet = 0;
    struct timeval sendTimeout;
    struct timeval recvTimeout;
    
    if (fd <= 0) return -1;
    
    sendTimeout.tv_sec = writeSec < 0 ? 0 : writeSec;
    sendTimeout.tv_usec = 0;
    recvTimeout.tv_sec = readSec < 0 ? 0 : readSec;
    recvTimeout.tv_usec = 0;
    
    if (setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, (const char *)&sendTimeout, sizeof(sendTimeout))) {
        GIZ_LOG_ERROR("setsockopt<SO_SNDTIMEO> errno %d: %s", errno, strerror(errno));
        iRet = -2;
    } else {
        if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&recvTimeout, sizeof(recvTimeout))) {
            GIZ_LOG_ERROR("setsockopt<SO_RCVTIMEO> errno %d: %s", errno, strerror(errno));
            iRet = -3;
        }
    }
    
    return iRet;
}

static double getDiffTime(struct timeval start, struct timeval end)
{
    double diffTime = 0;
    
    diffTime = end.tv_sec - start.tv_sec + (double)(end.tv_usec - start.tv_usec) / 1000000;
    
    return diffTime;
}

static void getIPByDomain(const char *domain, char ip[LOG_IP_BUF_LENGTH])
{
    int error = 0;
    struct timeval end;
    struct timeval start;
    struct addrinfo hints;
    struct addrinfo *result = NULL;
    struct addrinfo *pAddrInfo = NULL;
    
    if (!domain || !domain[0] || !ip) {
        GIZ_LOG_ERROR("Invalid parameter, domain %s, ip %s", domain, ip);
        return;
    }
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
#ifndef __ANDROID__
    hints.ai_flags = AI_ADDRCONFIG | AI_V4MAPPED;
#endif
    
    gettimeofday(&start, NULL);
    error = getaddrinfo(domain, 0, &hints, &result);
    if (error) {
        GIZ_LOG_ERROR("getaddrinfo failed, error %d: %s", error, gai_strerror(error));
    } else {
        pAddrInfo = result;
        while (pAddrInfo) {
            if (AF_INET == pAddrInfo->ai_family) {
                inet_ntop(AF_INET, &((struct sockaddr_in *)pAddrInfo->ai_addr)->sin_addr, ip, LOG_IP_BUF_LENGTH);
                break;
            }
#ifndef __ANDROID__
            else if (AF_INET6 == pAddrInfo->ai_family) {
                inet_ntop(AF_INET6, &((struct sockaddr_in6 *)pAddrInfo->ai_addr)->sin6_addr, ip, LOG_IP_BUF_LENGTH);
                break;
            }
#endif
            
            pAddrInfo = pAddrInfo->ai_next;
        }
    }
    gettimeofday(&end, NULL);
    GIZ_LOG_DEBUG("get IP %s from damain %s elapsed %.6fs", ip, domain, getDiffTime(start, end));
    
    if (result) freeaddrinfo(result);
}

static int createThread(void *(*pFunc)(void *), void *shareBuf)
{
    int iRet = 0;
    
    pthread_t threadID;
    if (pthread_create(&threadID, NULL, pFunc, shareBuf)) {
        iRet = -1;
    }
    
    return iRet;
}

static int newICMPSocket(void)
{
    int fd = 0;
    int iRet = 0;
    struct timeval timeout = { 2, 500000 }; //2.5s 超时
    
    fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if(fd <= 0) {
        GIZ_LOG_ERROR("socket failed errno %d: %s", errno, strerror(errno));
        iRet = -1;
    } else {
        if (setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, (const char *)&timeout, sizeof(timeout))) {
            GIZ_LOG_ERROR("setsockopt<SO_SNDTIMEO> errno %d: %s", errno, strerror(errno));
            iRet = -2;
        } else {
            if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, (const char *)&timeout, sizeof(timeout))) {
                GIZ_LOG_ERROR("setsockopt<SO_RCVTIMEO> errno %d: %s", errno, strerror(errno));
                iRet = -3;
            }
        }
    }
    
    return fd > 0 ? fd : iRet;
}

static inline unsigned short getICMPChecksum(const ICMPPHead_t *addr, int len)
{
    int sum = 0;
    int nleft = len;
    unsigned short answer = 0;
    unsigned short *w = (unsigned short *)addr;
    
    while(nleft > 1) {
        sum += *w++;
        nleft -= 2;
    }
    
    if( 1 == nleft) {
        *(unsigned char *)(&answer) = *(unsigned char *)w;
        sum += answer;
    }
    
    sum = (sum >> 16) + (sum & 0xffff);
    sum += (sum >> 16);
    answer = ~sum;
    
    return answer;
}

static inline void getCurTimestamp(unsigned long *pts)
{
    struct timeval ts = { 0 };
    
    gettimeofday(&ts, NULL);
    
    *pts = ts.tv_sec * 1000000 + ts.tv_usec;
}

static int sendICMPReq(int fd, const struct sockaddr *addr, unsigned short id,
                       unsigned short seq, int len, unsigned long *pts)
{
    char *packetICMP = NULL;
    ICMPPHead_t *pPacket = NULL;
    int iRet = 0;
    int packetLen = sizeof(ICMPPHead_t) + len;
    
    packetICMP = (char *)calloc(packetLen, 1);
    if (!packetICMP) {
        GIZ_LOG_ERROR("calloc %d bytes spaces failed, errno %d: %s", packetLen, strerror(errno));
        return -1;
    }
    
    getCurTimestamp(pts);
    pPacket = (ICMPPHead_t *)packetICMP;
    pPacket->type = 8;
    pPacket->id = id;
    pPacket->seq = seq;
    pPacket->timestamp = *pts;
    pPacket->crc = getICMPChecksum(pPacket, sizeof(ICMPPHead_t));
    
    iRet= (int)sendto(fd, packetICMP, packetLen, 0, addr, sizeof(struct sockaddr));
    free(packetICMP);
    
    if(iRet != packetLen) {
        if(ETIMEDOUT == errno || EAGAIN == errno) {
            GIZ_LOG_ERROR("packet send timeout");
            iRet = -2;
        } else {
            GIZ_LOG_ERROR("packet send failed, expect %d, return %d, errno %d: %s",
                          packetLen, iRet, errno, strerror(errno));
            iRet = -3;
        }
    }
    
    return iRet;
}

static int recvICMPResp(int fd, const struct sockaddr *pAddrOut, unsigned short id,
                        unsigned short seq, int len, unsigned long *pts)
{
    char *ipPacket = NULL;
    ICMPPHead_t packet = { 0 };
    struct sockaddr_in addrIn = { 0 };
    int iRet = 0;
    int addrLen = sizeof(struct sockaddr);
    int packetLen = sizeof(struct ip) + sizeof(ICMPPHead_t) + len;
    
    ipPacket = (char *)calloc(packetLen, 1);
    if(!ipPacket) {
        GIZ_LOG_ERROR("calloc %d bytes spaces failed, errno %d: %s", errno, strerror(errno));
        return -1;
    }
    
    iRet = (int)recvfrom(fd, ipPacket, packetLen, 0, (struct sockaddr *)&addrIn, (socklen_t *)&addrLen);
    if (iRet != packetLen) {
        if(ETIMEDOUT == errno || EAGAIN == errno) {
            GIZ_LOG_ERROR("packet recv timeout, errno %d: %s", errno, strerror(errno));
            iRet = -2;
        } else {
            GIZ_LOG_ERROR("packet send failed, expect %d, return %d, errno %d: %s",
                          packetLen, iRet, errno, strerror(errno));
            iRet = -3;
        }
    } else {
        packet = *(ICMPPHead_t *)(ipPacket + sizeof(struct ip));
        
        //IP与type判断
        if(memcmp(&addrIn.sin_addr, &((struct sockaddr_in *)pAddrOut)->sin_addr, sizeof(struct in_addr))) {
            GIZ_LOG_ERROR("addr is not equal");
            iRet = -4;
        } else if (packet.type != 0) {
            GIZ_LOG_ERROR("type invalid");
            iRet = -5;
        } else if (getICMPChecksum(&packet, sizeof(ICMPPHead_t)) != 0) {
            GIZ_LOG_ERROR("checksum failed");
            iRet = -6;
        } else if (packet.id != id) {
            GIZ_LOG_ERROR("id not match");
            iRet = -7;
        } else if (packet.seq != seq) {
            GIZ_LOG_DEBUG("seq not match, continue...");
        }
    }
    
    free(ipPacket);
    getCurTimestamp(pts); //记录结束时间(微秒数)
    
    return iRet;
}

static void pingBaidu(double *elapsed)
{
    unsigned short id = 0;
    int i = 0;
    int iRet = 0;
    int len = 32; //请求的包长度
    int count = 4; //次数
    int pingCount = 0; //已请求的次数
    int fd = newICMPSocket(); //建立ICMP套接字
    unsigned long tsSum = 0; //总延迟
    unsigned long tsEnd = 0; //结束时间
    unsigned long tsStart = 0; //开始时间
    unsigned long tsElapsed = 0; //单次延时
    struct sockaddr_in addr = { 0 };
    char ip[LOG_IP_BUF_LENGTH + 1] = { 0 };
    const char *errorStr = NULL;
    
    if(fd < 0) return;
    
    //DNS解析
    getIPByDomain("www.baidu.com", ip);
    if (!ip[0]) {
        close(fd);
        GIZ_LOG_ERROR("getIPByDomain failed");
        return;
    }
    
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr(ip);
    
    id = (unsigned short)pthread_self();
    
    //业务日志
    GIZ_LOG_BIZ("ping_baidu_start", "", "ping baidu: ip = %s", ip);
    GIZ_LOG_DEBUG("Try to ping www.baidu.com, ip %s, id %d", ip, id);
    
    for (i = 0; i < count; i++) {
        iRet = (int)sendICMPReq(fd, (struct sockaddr *)&addr, id, i, len, &tsStart);
        if(-5 == iRet) continue;
        if(iRet < 0) break;
        
        iRet = (int)recvICMPResp(fd, (struct sockaddr *)&addr, id, i, len, &tsEnd);
        if(-4 == iRet) continue;
        if(iRet < 0) break;
        
        //计算延迟
        tsElapsed = tsEnd - tsStart;
        GIZ_LOG_DEBUG("ping %s, id: %i, seq: %i, elapsed: %.3lfms",
                      ip, id, i, tsElapsed / 1000.0);
        tsSum += tsElapsed;
        
        //成功接收ping的次数
        ++pingCount;
    }
    
    //求平均值，清理
    *elapsed = tsSum / ((double)pingCount) / 1000.0;
    close(fd);
    
    //发送或者接收失败，则不改相应的错误码
    if(iRet >= 0) {
        iRet = 0;
        errorStr = "GIZ_LOG_SUCCESS";
    } else if (-1 == iRet) {
        errorStr = "GIZ_LOG_MEMORY_MALLOC_FAILED";
    } else if (-2 == iRet) {
        errorStr = "GIZ_LOG_SEND_OR_RECV_TIMEOUT";
    } else {
        errorStr = "GIZ_LOG_PING_ERROR";
    }
    
    //业务日志
    GIZ_LOG_BIZ("ping_baidu_result", errorStr, "ping baidu time elapsed: %.3lf ms", *elapsed);
    GIZ_LOG_ERROR("ping %s, id %d, iRet %i, average %.3lfms", ip, id, iRet, *elapsed);
}

static void *pingBaiduSync(void *argv)
{
    double timeout = 0.0;
    
    signal(SIGPIPE, SIG_IGN);
    pthread_detach(pthread_self());
    
    pingBaidu(&timeout);
    
    return NULL;
}

static void pingBaiduAsync(void)
{
    //启动线程
    if (createThread(pingBaiduSync, NULL)) {
        GIZ_LOG_ERROR("createThread pingBaiduSync failed errno %d: %s",
                      errno, strerror(errno));
    }
}

static int sslWriten(SSL *sslHandle, const void *buf, size_t n)
{
    size_t nleft;
    ssize_t nwritten;
    const char *ptr;
    
    if (!sslHandle) return -1;
    
    ptr = (const char *)buf;
    nleft = n;
    while (nleft > 0) {
        if ((nwritten = SSL_write(sslHandle, ptr, (int)nleft)) <= 0) {
            if (nwritten < 0 && errno == EINTR)
                nwritten = 0;
            else
                return (-1);
        }
        nleft -= nwritten;
        ptr += nwritten;
    }
    
    return (int)n;
}

static int sslReadn(SSL *sslHandle, void *buf, size_t n)
{
    size_t nleft;
    ssize_t nread;
    char *ptr;
    
    ptr = (char *) buf;
    nleft = n;
    while (nleft > 0) {
        if ((nread = SSL_read(sslHandle, ptr, (int)nleft)) < 0) {
            if (EINTR == errno)
                nread = 0;
            else
                return -1;
        } else if (nread == 0) {
            break;
        }
        
        nleft -= nread;
        ptr += nread;
    }
    
    return (int)(n - nleft);
}

static int connectByIPPort(const char *ip, int port, int timeoutSec)
{
    int fd = 0;
    int yes = 1;
    int error = 0;
    char portStr[16] = { 0 };
    struct timeval end;
    struct timeval start;
    struct addrinfo hints;
    struct addrinfo *pAddr = NULL;
    
    if (!ip || !ip[0] || port <= 0) return -1;
    
    //兼容IPv4跟IPv6
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
#ifndef __ANDROID__
    hints.ai_flags = AI_ADDRCONFIG | AI_V4MAPPED;
#endif
    snprintf(portStr, sizeof(portStr), "%d", port);
    error = getaddrinfo(ip, portStr, &hints, &pAddr);
    if (error) {
        GIZ_LOG_ERROR("getaddrinfo failed, return %d: %s",
                      error, gai_strerror(error));
        freeaddrinfo(pAddr);
        return -1;
    }
    
    fd = socket(pAddr->ai_family, pAddr->ai_socktype, pAddr->ai_protocol);
    if (fd <= 0) {
        
        GIZ_LOG_ERROR("create socket for family %d failed, errno %d: %s",
                      pAddr->ai_family, errno, strerror(errno));
        freeaddrinfo(pAddr);
        return -2;
    }
    
    //允许端口复用
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (const char *)&yes, sizeof(int))) {
        GIZ_LOG_ERROR("setsockopt<SO_REUSEADDR> errno %d: %s", errno, strerror(errno));
        GIZ_CLOSE(fd);
        freeaddrinfo(pAddr);
        return -3;
    }
    
#ifdef __APPLE__
    //设置TCP连接超时时间(iOS系统支持设置该套接字选项)
    if (setsockopt(fd, IPPROTO_TCP, TCP_CONNECTIONTIMEOUT, &timeoutSec, sizeof(timeoutSec))) {
        GIZ_LOG_ERROR("setsockopt<TCP_CONNECTIONTIMEOUT> errno %d: %s", errno, strerror(errno));
        GIZ_CLOSE(fd);
        freeaddrinfo(pAddr);
        return -4;
    }
#endif
    
    if (setSockTime(fd, timeoutSec, timeoutSec)) {
        GIZ_LOG_ERROR("setSockTime failed errno %d: %s", errno, strerror(errno));
        GIZ_CLOSE(fd);
        freeaddrinfo(pAddr);
        return -5;
    }
    
    gettimeofday(&start, NULL);
    if (connect(fd, pAddr->ai_addr, pAddr->ai_addrlen)) {
        gettimeofday(&end, NULL);
        GIZ_LOG_ERROR("connect to %s port %d failed errno %d: %s, elapsed %.6fs",
                      ip, port, errno, strerror(errno), getDiffTime(start, end));
        if (ETIMEDOUT == errno) {
            pingBaiduAsync();
        }
        GIZ_CLOSE(fd);
        freeaddrinfo(pAddr);
        return -6;
    } else {
        gettimeofday(&end, NULL);
        GIZ_LOG_DEBUG("connect to %s port %d success, fd %d, elapsed %.6fs",
                      ip, port, fd, getDiffTime(start, end));
        freeaddrinfo(pAddr);
        return fd;
    }
}

static void sslConnectionFree(sslConnection_st *sslConnection)
{
    if (!sslConnection) return;
    
    if (sslConnection->handle) {
        SSL_shutdown(sslConnection->handle);
        SSL_free(sslConnection->handle);
    }
    if (sslConnection->context) {
        SSL_CTX_free(sslConnection->context);
    }
    if (sslConnection->fd > 0) {
        GIZ_CLOSE(sslConnection->fd);
    }
    
    free(sslConnection);
}

static sslConnection_st *sslConnectByIPPort(const char *ip, int port, int timeoutSec)
{
    int fd = 0;
    int failedFlag = 1;
    sslConnection_st *sslConnection = NULL;
    
    sslConnection = (sslConnection_st *)malloc(sizeof(sslConnection_st));
    if (sslConnection) {
        memset(sslConnection, 0, sizeof(sslConnection_st));
        // Register the available ciphers and digests
        SSL_library_init ();
        
        // New context saying we are a client, and using TLSv1.2
        sslConnection->context = SSL_CTX_new(TLSv1_2_client_method());
        if (sslConnection->context) {
            // Create an SSL struct for the connection
            sslConnection->handle = SSL_new(sslConnection->context);
            if (sslConnection->handle) {
                fd = connectByIPPort(ip, port, timeoutSec);
                if (fd > 0) {
                    sslConnection->fd = fd;
                    // Connect the SSL struct to our connection
                    if (1 == SSL_set_fd(sslConnection->handle, fd)) {
                        // Initiate SSL handshake
                        if (1 == SSL_connect(sslConnection->handle)) {
                            failedFlag = 0;
                        } else {
                            GIZ_LOG_ERROR("SSL handshake, SSL_connect failed, %s", strerror(errno));
                        }
                    }
                } else {
                    GIZ_LOG_ERROR("connectByIPPort %s:%d failed, return %d, errno %d, %s",
                                  ip, port, fd, errno, strerror(errno));
                    if (ETIMEDOUT == errno) {
                        pingBaiduAsync();
                    }
                }
            }
        }
        
        if (failedFlag) {
            sslConnectionFree(sslConnection);
            sslConnection = NULL;
        }
    } else {
        GIZ_LOG_ERROR("malloc a %lu bytes of space failed, errno %d: %s",
                      sizeof(sslConnection_st), errno, strerror(errno));
    }
    
    return sslConnection;
}

static char *httpsPost(const char *domain, int port, int timeoutSec, const char *dest, const char *headCustom,
                       const char *content, int *answerLen, int *responseCode)
{
    int iRet = 0;
    int iLen = 0;
    int index = 0;
    int headLen = 0;
    int contentLen = 0;
    int remainLength = 0;
    char isTransferEncoding = 0;
    char *pEnd = NULL;
    char *answer = NULL;
    char *pStart = NULL;
    sslConnection_st *sslConnection = NULL;
    char ip[LOG_IP_BUF_LENGTH + 1] = { 0 };
    char buf[LOG_SEND_BUF_LENGTH + 1] = { 0 };
    
    if (!domain || !domain[0] || !dest || !dest[0] || port < 0|| !answerLen) {
        GIZ_LOG_ERROR("Invalid parameter, domain %s, dest %s, port %d, answerLen %p",
                      domain, dest, port, answerLen);
        return NULL;
    }
    
    //初始化,取Content-Length
    *responseCode = 0;
    contentLen = (int)(content ? strlen(content) : 0);
    
    //组HTTP请求行+信息报头数据包
    snprintf(buf, sizeof(buf), "POST %s HTTP/1.1\r\n"
             "Host: %s\r\n"
             "Content-Length: %d\r\n"
             "%s"
             "Connection: keep-alive\r\n\r\n",
             dest, domain, contentLen, headCustom ? headCustom : "");
    headLen = (int)strlen(buf);
    
    //通过域名获取对应的IP
    getIPByDomain(domain, ip);
    if (!ip[0]) {
        GIZ_LOG_ERROR("getIPByDomain failed, domain:%s", domain);
    } else {
        //通过IP，端口创建限时的TCP套接字
        sslConnection = sslConnectByIPPort(ip, port, timeoutSec);
        if (sslConnection) {
            //发送请求数据
            iRet = sslWriten(sslConnection->handle, buf, headLen);
            if (iRet != headLen) {
                GIZ_LOG_ERROR("sslWriten to fd %d failed, expect %d, return %d, errno %d: %s",
                              sslConnection->fd, headLen, iRet, errno, strerror(errno));
            } else {
                GIZ_LOG_DEBUG("sslWriten HTTPS head to %s:%d success: %s", domain, port, buf);
                iRet = sslWriten(sslConnection->handle, content ? content : "", contentLen);
                if (iRet != contentLen) {
                    GIZ_LOG_ERROR("sslWriten to fd %d failed, expect %d, return %d, errno %d: %s",
                                  sslConnection->fd, contentLen, iRet, errno, strerror(errno));
                } else {
                    GIZ_LOG_DEBUG("sslWriten https body:%s", content ? content : "");
                    
                    //读取完整的HTTP返回包数据
                    memset(buf, 0, sizeof(buf));
                    while ((iRet = sslReadn(sslConnection->handle, buf + index, 1)) > 0 &&
                           !strstr(buf, "\r\n\r\n") && ++index < sizeof(buf));
                    
                    //解析收到的数据包
                    if (iRet > 0) {
                        GIZ_LOG_DEBUG("https response:\n%s", buf);
                        
                        //取到HTTPS回复的状态码
                        pStart = strstr(buf, " ");
                        pEnd = strstr(++pStart, " ");
                        if (pEnd) {
                            pEnd[0] = '\0';
                        }
                        *responseCode = atoi(pStart);
                        if (pEnd) {
                            pEnd[0] = ' ';
                        }
                        
                        //Content-Length方式解析HTTP包体长度
                        pStart = strcasestr(buf, "Content-Length:");
                        if (pStart) {
                            pEnd = strstr(pStart, "\r\n");
                            if (pEnd) {
                                pEnd[0] = '\0';
                                *answerLen = atoi(pStart + strlen("Content-Length:"));
                                pEnd[0] = '\r';
                                pEnd = strstr(pEnd, "\r\n\r\n");
                                if (pEnd) {
                                    pEnd += strlen("\r\n\r\n");
                                }
                            }
                        }
                        
                        //Transfer-Encoding方式解析HTTP包体长度
                        pStart = strcasestr(buf, "Transfer-Encoding:");
                        if (pStart) {
                            isTransferEncoding = 1;
                            pEnd = strstr(pStart, "\r\n\r\n");
                        }
                    } else {
                        GIZ_LOG_ERROR("sslReadn failed, return %d, errno %d: %s",
                                      iRet, errno, strerror(errno));
                    }
                    
                    //读取并解析正文数据
                    if (pEnd) {
                        if (isTransferEncoding) {
                            //初始化
                            index = 0;
                            memset(buf, 0, sizeof(buf));
                            while (index < sizeof(buf) && sslReadn(sslConnection->handle, buf + index, 1) > 0) {
                                ++index;
                                
                                if ((pEnd = strstr(buf + 1, "\r\n"))) {
                                    pEnd[0] = '\0';
                                    if (remainLength) {
                                        //如果是后续ChunckedSize字段,则偏移"\r\n"到下一包的长度部分
                                        sscanf(buf + strlen("\r\n"), "%x", &remainLength);
                                    } else {
                                        //如果是首个ChunckedSize字段,则无须偏移直接是包长部分
                                        sscanf(buf, "%x", &remainLength);
                                    }
                                    pEnd[0] = '\r';
                                    if (remainLength < 0) {
                                        GIZ_LOG_ERROR("invalid http ChunckedSize:%d", remainLength);
                                        if (answer) free(answer);
                                        answer = NULL;
                                        break; //ChunckedSize长度非法视为HTTP应答参数错误,放弃数据,退出循环
                                    } else if (!remainLength) {
                                        //后续包长度为0视为结束,读掉\r\n再退出循环
                                        sslReadn(sslConnection->handle, buf + index, strlen("\r\n"));
                                        break;
                                    }
                                    
                                    *answerLen += remainLength;
                                    GIZ_LOG_DEBUG("https ChunckedSize:%d, sumSize:%d", remainLength, *answerLen);
                                    answer = (char *)realloc(answer, *answerLen + 1);
                                    if (answer) {
                                        answer[*answerLen] = '\0';
                                        iRet = sslReadn(sslConnection->handle, answer + *answerLen - remainLength, remainLength);
                                        if (iRet != remainLength) {
                                            GIZ_LOG_ERROR("sslReadn return %d, expect %d, errno %d: %s",
                                                          iRet, remainLength, errno, strerror(errno));
                                            free(answer);
                                            answer = NULL;
                                            break;
                                        }
                                    } else {
                                        GIZ_LOG_ERROR("realloc a size of %d space failed, errno %d: %s",
                                                      *answerLen + 1, errno, strerror(errno));
                                        break;
                                    }
                                    
                                    index = 0;
                                    memset(buf, 0, sizeof(buf));
                                }
                            }
                        } else {
                            if (*answerLen > 0) {
                                GIZ_LOG_DEBUG("https Content-Length:%d", *answerLen);
                                answer = (char *) malloc(*answerLen + 1);
                                if (answer) {
                                    answer[*answerLen] = '\0';
                                    iRet = sslReadn(sslConnection->handle, answer, *answerLen);
                                    if (iRet != *answerLen) {
                                        free(answer);
                                        answer = NULL;
                                        GIZ_LOG_ERROR("sslReadn return %d, expect %d, errno %d: %s",
                                                      iRet, *answerLen, errno, strerror(errno));
                                    }
                                } else {
                                    GIZ_LOG_ERROR("malloc a size of %d space failed, errno %d: %s",
                                                  *answerLen + 1, errno, strerror(errno));
                                }
                            }
                        }
                    } else {
                        if (iRet > 0) {
                            GIZ_LOG_ERROR("response invalid https head: %s", buf);
                        }
                    }
                }
            }
            
            sslConnectionFree(sslConnection);
        } else {
            GIZ_LOG_ERROR("sslConnectByIPPort %s:%d failed, errno %d, %s",
                          ip, port, errno, strerror(errno));
        }
    }
    
    if (!answer && iLen != 0) {
        *answerLen = 0;
    }
    
    return answer;
}

static void mkdirs(const char *dirs)
{
    int i = 0;
    int len = 0;
    char path[LOG_MAX_PATH_LEN + 1] = { 0 };
    
    if (!dirs) return;
    
    strncpy(path, dirs, sizeof(path) - 1);
    len = (int)strlen(dirs);
    
    for(i = 0; i < len; ++i) {
        if('/' == path[i]) {
            path[i] = '\0';
            if (access(path, 0)) {
                mkdir(path, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
            }
            path[i] = '/';
        }
    }
    
    if(len > 0 && access(path, 0)) {
        mkdir(path, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    }
}

static const char *printSysInfo(const char *fileName, int fileLine, const char *function)
{
    snprintf(gSysInfoLogBuf, sizeof(gSysInfoLogBuf), "[APPSYS][DEBUG][%s][%s:%d %s][GizLog Version:%s, sysInfoJson:%s]",
             GizTimeStr(), __FILENAME__, __LINE__, __FUNCTION__, gGizLogVersion, gGizLog.sysInfoJson);
    
    return gSysInfoLogBuf;
}

static char *getFileContentByPath(const char *path)
{
    FILE *file = NULL;
    char *fileContent = NULL;
    struct stat fileStat = { 0 };
    
    if (!stat(path, &fileStat)) {
        file = fopen(path, "r");
        if (file) {
            fileContent = (char *)malloc((size_t)fileStat.st_size + 1);
            if (fileContent) {
                fread(fileContent, 1, (size_t)fileStat.st_size, file);
                fileContent[fileStat.st_size] = 0;
            } else {
                GIZ_LOG_ERROR("malloc %d bytes space filed, errno %d: %s",
                                       fileStat.st_size + 1, errno, strerror(errno));
            }
            
            fclose(file);
        }
    }
    
    return fileContent;
}

static int listenFileForUploadByPath(const char *path)
{
    int answerLen = 0;
    int httpBodyLen = 0;
    int responseCode = 0;
    char *answer = NULL;
    char *httpBody = NULL;
    char *fileContent = NULL;
    char httpHeadCustom[LOG_SEND_BUF_LENGTH] = { 0 };
    
    fileContent = getFileContentByPath(path);
    if (fileContent) {
        snprintf(httpHeadCustom, sizeof(httpHeadCustom),
                 "X-Gizwits-Application-Id: %s\r\n"
                 "X-Gizwits-User-token: %s\r\n"
                 "Content-Type: multipart/form-data; boundary=%s\r\n",
                 gGizLog.appID, gGizLog.token, LOG_HTTP_BOUNDARY);
        httpBodyLen = (int)strlen(fileContent) + 1024; //填充boundary部分新增1K足够
        httpBody = (char *)malloc(httpBodyLen);
        if (httpBody) {
            snprintf(httpBody, httpBodyLen, "--%s\r\n"
                     "Content-Disposition: form-data; name=\"logfile\"; filename=\"GizLogFile.old\"\r\n"
                     "Content-Type: application/octet-stream\r\n\r\n"
                     "%s"
                     "\r\n"
                     "--%s--\r\n",
                     LOG_HTTP_BOUNDARY, fileContent, LOG_HTTP_BOUNDARY);
            
            answer = httpsPost(gGizLog.domain, gGizLog.sslPort, LOG_HTTP_TIMEOUT,
                               "/app/logging", httpHeadCustom, httpBody, &answerLen, &responseCode);
            //打印结果
            GIZ_LOG_DEBUG("Upload Log HTTPS responseCode:%d, body:%s, upload file:%s",
                          responseCode, answer, path);
            
            if (answer) free(answer);
            free(httpBody);
        } else {
            GIZ_LOG_ERROR("malloc %d bytes space filed, errno %d: %s",
                          httpBodyLen, errno, strerror(errno));
        }
        
        free(fileContent);
    }
    
    return responseCode;
}

static void logRenameSys(void)
{
    char curPath[LOG_MAX_PATH_LEN] = { 0 };
    char oldPath[LOG_MAX_PATH_LEN] = { 0 };
    
    //处理系统日志文件
    if (gGizLog.fileSys) fclose(gGizLog.fileSys);
    snprintf(curPath, sizeof(curPath), "%s%s.sys", gGizLog.dir, LOG_FILE_NAME);
    snprintf(oldPath, sizeof(oldPath), "%s.old", curPath);
    remove(oldPath);  //先删除旧的日志文件
    rename(curPath, oldPath);  //再将当前日志文件重命名为老的日志文件
    gGizLog.fileSys = fopen(curPath, "a+");  //新建文件存储新日志
    if (gGizLog.fileSys) {
        gGizLog.latestCreatSysLogTimestamp = time(NULL);
        fprintf(gGizLog.fileSys, "%s\n", printSysInfo(__FILENAME__, __LINE__, __FUNCTION__));
        fflush(gGizLog.fileSys);
    }
}

static void logRenameBiz(void)
{
    struct stat statBuf;
    char curPath[LOG_MAX_PATH_LEN] = { 0 };
    char oldPath[LOG_MAX_PATH_LEN] = { 0 };
    
    //处理业务日志文件
    if (gGizLog.fileBiz) fclose(gGizLog.fileBiz);
    snprintf(curPath, sizeof(curPath), "%s%s.biz", gGizLog.dir, LOG_FILE_NAME);
    snprintf(oldPath, sizeof(oldPath), "%s.old", curPath);
    //非空业务日志文件才需要重命名待上传
    stat(curPath, &statBuf);
    if (statBuf.st_size > 0) {
        remove(oldPath);  //先删除旧的日志文件
        rename(curPath, oldPath);  //再将当前日志文件重命名为老的日志文件
    }
    gGizLog.fileBiz = fopen(curPath, "a+");  //新建文件存储新日志
    if (gGizLog.fileBiz) {
        gGizLog.latestCreatBizLogTimestamp = time(NULL);
    }
}

static void renameOldToUploaded(const char *oldPath)
{
    char uploadPath[LOG_MAX_PATH_LEN] = { 0 };
    
    snprintf(uploadPath, sizeof(uploadPath), "%s.uploaded", oldPath);
    remove(uploadPath);  //先删除旧的.old.uploaded文件
    rename(oldPath, uploadPath);  //再将.old文件重命名为.old.uploaded文件
}

static void mergeOldToUploadedBizLog(const char *oldPath)
{
    int oldFileSize = 0;
    FILE *uploadFile = NULL;
    char *oldFileContent = NULL;
    struct stat fileStat = { 0 };
    char uploadPath[LOG_MAX_PATH_LEN] = { 0 };
    
    //读取刚上传的旧文件内容
    oldFileContent = getFileContentByPath(oldPath);
    remove(oldPath); //读取完内容后可删除
    if (oldFileContent) {
        oldFileSize = (int)strlen(oldFileContent);
    } else {
        return;
    }
    
    //判断已上传文件大小是否超标并将其打开
    snprintf(uploadPath, sizeof(uploadPath), "%s.uploaded", oldPath);
    if (!stat(uploadPath, &fileStat)) {
        
        if (fileStat.st_size >= LOG_MAX_UPLOADED_FILE_SIZE) {
            remove(uploadPath);
        }
    }
    uploadFile = fopen(uploadPath, "a+");
    
    if (uploadFile) {
        //将刚上传文件内容追加到已上传文件中去
        fwrite(oldFileContent, 1, oldFileSize, uploadFile);
        fflush(uploadFile);
        fclose(uploadFile);
    }
    
    free(oldFileContent);
}

static void mergeUnuploadOldAndNewBizLog(const char *oldPath)
{
    int oldFileSize = 0;
    char *oldFileContent = NULL;
    
    //读取待重传的旧文件内容
    oldFileContent = getFileContentByPath(oldPath);
    if (oldFileContent) {
        oldFileSize = (int)strlen(oldFileContent);
    } else {
        return;
    }
    
    pthread_mutex_lock(&gMutexGizLog);
    //将旧文件内容插入新文件头
    if (gGizLog.fileBiz) {
        fseek(gGizLog.fileBiz, 0L, SEEK_SET); //偏移到文件头
        fwrite(oldFileContent, 1, oldFileSize, gGizLog.fileBiz);
        fflush(gGizLog.fileBiz);
        fseek(gGizLog.fileBiz, 0L, SEEK_END); //偏移到文件尾
    }
    pthread_mutex_unlock(&gMutexGizLog);
    
    free(oldFileContent);
}

static void *threadUpload(void *argv)
{
    char oldPath[LOG_MAX_PATH_LEN] = { 0 };
    
    signal(SIGPIPE, SIG_IGN);
    pthread_detach(pthread_self());
    
    //需要上传则一直上传日志
    while (1) {
        //APPID非空方能上传
        if (gGizLog.appID[0]) {
            if (!gUploadedTheInitLog ||
                (gGizLog.latestCreatSysLogTimestamp && gGizLog.uploadSystemLog &&
                 time(NULL) - gGizLog.latestCreatSysLogTimestamp > LOG_MAX_RENAME_SYS_TIME)) {
                    pthread_mutex_lock(&gMutexGizLog);
                    logRenameSys();
                    pthread_mutex_unlock(&gMutexGizLog);
                }
            if (!gUploadedTheInitLog ||
                (gGizLog.latestCreatBizLogTimestamp && gGizLog.uploadBusinessLog &&
                 time(NULL) - gGizLog.latestCreatBizLogTimestamp > LOG_MAX_RENAME_BIZ_TIME)) {
                    pthread_mutex_lock(&gMutexGizLog);
                    logRenameBiz();
                    pthread_mutex_unlock(&gMutexGizLog);
                }
            gUploadedTheInitLog = 1;
            
            if (gGizLog.uploadBusinessLog) {
                snprintf(oldPath, sizeof(oldPath), "%s%s.biz.old", gGizLog.dir, LOG_FILE_NAME);
                if (listenFileForUploadByPath(oldPath)) {
                    mergeOldToUploadedBizLog(oldPath);
                } else {
                    mergeUnuploadOldAndNewBizLog(oldPath);
                    remove(oldPath);
                }
            }
            
            if (gGizLog.uploadSystemLog) {
                snprintf(oldPath, sizeof(oldPath), "%s%s.sys.old", gGizLog.dir, LOG_FILE_NAME);
                if (listenFileForUploadByPath(oldPath)) {
                    renameOldToUploaded(oldPath);
                }
            }
        }
        
        sleep(1);
    }
    
    return NULL;
}

/**
 * @brief 日志初始化.
 * @param[in] sysInfoJson- 系统信息(Json字符串，例:{"phone_id":"AE27466D-9C8F-4184-A6A3-2A0CDEDAA4FD","os":"iOS","os_ver":"9.2","app_version":"1.5.1","phone_model":"iPhone 6 (A1549/A1586)"}).
 * @param[in] logDir- 存储日志目录的路径(推荐采用程序私有目录,例:/var/mobile/Containers/Data/Application/1D7A5CD8-70D2-4B46-A76A-8B9BE5CBC88C/Documents").
 * @param[in] printLevel- 日志打印到屏幕的级别(0:不打印屏幕,1:打印error+busi,2:打印error+debug+busi).
 * @return 返回日志初始化结果,0:成功,1:sysInfoJson非法,2:logDir指定错误(目录为空、不存在或无法创建文件等),3:printLevel非法,4:创建日志上传线程失败.
 *
 */
int GizLogInit(const char *sysInfoJson, const char *logDir, int printLevel)
{
    int iRet = 0;
    char curPath[LOG_MAX_PATH_LEN] = { 0 };
    char addFolderLogDir[LOG_MAX_PATH_LEN] = { 0 };
    
    if (!sysInfoJson || !sysInfoJson[0]) iRet = 1;
    if (!logDir || !logDir[0]) iRet = 2;
    if (printLevel < 0 || printLevel > 3) iRet = 3;
    
    //创建日志目录
    if (0 == iRet) {
        if (!gInitedGizLogMutex) {
            gInitedGizLogMutex = 1;
            pthread_mutex_init(&gMutexGizLog, NULL);
            
            if (createThread(threadUpload, NULL)) {
                iRet = 4;
            }
        }
        
        if (0 == iRet) {
            if (logDir[strlen(logDir) - 1] != '/') {
                snprintf(addFolderLogDir, sizeof(addFolderLogDir), "%s/GizLog/", logDir);
            } else {
                snprintf(addFolderLogDir, sizeof(addFolderLogDir), "%sGizLog/", logDir);
            }
            mkdirs(addFolderLogDir);
            if (access(addFolderLogDir, 0)) iRet = 2;
        }
    }
    
    if (0 == iRet) {
        pthread_mutex_lock(&gMutexGizLog);
        
        if (gGizLog.fileBiz) {
            fclose(gGizLog.fileBiz);  //重新设置日志参数统一先关闭已打开的业务日志文件
            gGizLog.fileBiz = NULL;
        }
        
        if (gGizLog.fileSys) {
            fclose(gGizLog.fileSys);  //重新设置日志参数统一先关闭已打开的系统日志文件
            gGizLog.fileSys = NULL;
        }
        
        if (gGizLog.sysInfoJson) {
            free(gGizLog.sysInfoJson);
            gGizLog.sysInfoJson = NULL;
        }
        
        snprintf(curPath, sizeof(curPath), "%s%s.biz", addFolderLogDir, LOG_FILE_NAME);
        //a：以写的方式打开业务日志文件，如果业务日志文件不存在则创建，如果存在则将新内容追加到文件末端
        gGizLog.fileBiz = fopen(curPath, "a+");
        if (NULL == gGizLog.fileBiz) {
            //创建业务日志文件失败尝试使用上次的路径
            if (gGizLog.dir[0]) {
                snprintf(curPath, sizeof(curPath), "%s%s.biz", gGizLog.dir, LOG_FILE_NAME);
                gGizLog.fileBiz = fopen(curPath, "a+");
                if (gGizLog.fileBiz) {
                    //a：以写的方式打开系统日志文件，如果系统日志文件不存在则创建，如果存在则将新内容追加到文件末端
                    snprintf(curPath, sizeof(curPath), "%s%s.sys", addFolderLogDir, LOG_FILE_NAME);
                    gGizLog.fileSys = fopen(curPath, "a+");
                    gGizLog.latestCreatSysLogTimestamp = time(NULL);
                    
                    gGizLog.sysInfoJson = (char *)malloc(strlen(sysInfoJson) + 1);
                    if (gGizLog.sysInfoJson) {
                        strcpy(gGizLog.sysInfoJson, sysInfoJson);
                        gGizLog.printLevel = printLevel;
                    } else {
                        iRet = 1;
                    }
                }
            }
            
            iRet = 2;
        } else {
            //a：以写的方式打开系统日志文件，如果系统日志文件不存在则创建，如果存在则将新内容追加到文件末端
            snprintf(curPath, sizeof(curPath), "%s%s.sys", addFolderLogDir, LOG_FILE_NAME);
            gGizLog.fileSys = fopen(curPath, "a+");
            gGizLog.latestCreatSysLogTimestamp = time(NULL);
            
            gGizLog.sysInfoJson = (char *)malloc(strlen(sysInfoJson) + 1);
            if (gGizLog.sysInfoJson) {
                strcpy(gGizLog.sysInfoJson, sysInfoJson);
            } else {
                iRet = 1;
            }
            gGizLog.printLevel = printLevel;
            strncpy(gGizLog.dir, addFolderLogDir, sizeof(gGizLog.dir) - 1);
        }
        
        pthread_mutex_unlock(&gMutexGizLog);
    }
    
    GIZ_LOG_DEBUG("log init with <sysInfoJson:%s,logDir:%s,printLevel:%d> return %d",
                           sysInfoJson, logDir, printLevel, iRet);;
    
    return iRet;
}

static void *threadProvision(void *argv)
{
    int answerLen = 0;
    int responseCode = 0;
    char *pEnd = NULL;
    char *pStart = NULL;
    char *answer = NULL;
    char replacedChar = 0;
    char httpHeadCustom[LOG_SEND_BUF_LENGTH] = { 0 };
    
    signal(SIGPIPE, SIG_IGN);
    pthread_detach(pthread_self());
    
    //Provision
    snprintf(httpHeadCustom, sizeof(httpHeadCustom),
             "Content-Type: application/json\r\n"
             "X-Gizwits-Application-Id: %s\r\n"
             "X-Gizwits-User-token: %s\r\n", gGizLog.appID, gGizLog.token);
    answer = httpsPost(gGizLog.domain, gGizLog.sslPort, LOG_HTTP_TIMEOUT,
                       "/app/provision", httpHeadCustom, gGizLog.sysInfoJson, &answerLen, &responseCode);
    //打印结果
    GIZ_LOG_DEBUG("Provision HTTPS responseCode:%d, body:%s", responseCode, answer);
    
    if (answer && LOG_HTTP_STATUS_OK == responseCode) {
        GIZ_LOG_BIZ("provision_resp", "GIZ_LOG_SUCCESS", "provision %s response %s",
                    gGizLog.sysInfoJson, answer);
        
        //解析saveSystemLog
        pStart = strstr(answer, "\"sys_log\":");
        if (pStart) {
            pEnd = strchr(pStart, ',');
            if (!pEnd) pEnd = strchr(pStart, '}');
            if (pEnd) {
                replacedChar = pEnd[0];
                pEnd[0] = '\0';
                gGizLog.uploadSystemLog = atoi(pStart + strlen("\"sys_log\":"));
                pEnd[0] = replacedChar;
            }
        }
        
        //解析saveBusinessLog
        pStart = strstr(answer, "\"biz_log\":");
        if (pStart) {
            pEnd = strchr(pStart, ',');
            if (!pEnd) pEnd = strchr(pStart, '}');
            if (pEnd) {
                replacedChar = pEnd[0];
                pEnd[0] = '\0';
                gGizLog.uploadBusinessLog = atoi(pStart + strlen("\"biz_log\":"));
                pEnd[0] = replacedChar;
            }
        }
    } else {
        GIZ_LOG_BIZ("provision_resp", "GIZ_LOG_HTTP_REQUEST_FAILED", "provision response code %d",
                    responseCode);
    }
    
    //临时绕过provision时打开如下注释
    //gGizLog.uploadSystemLog = 1;
    //gGizLog.uploadBusinessLog = 1;
    
    //释放资源
    if (answer) free(answer);
    
    return NULL;
}

/**
 * @brief 日志上传检测,如要上传则新建线程上传日志.
 * @param[in] openAPIDomain OpenAPI服务器域名.
 * @param[in] openAPISSLPort OpenAPI服务器SSL端口.
 * @param[in] appID- 指定应用标识地址.
 * @param[in] uid- 指定用户标识码地址.
 * @param[in] token- 指定远程用户令牌地址.
 * @return 日志上传检测结果,0:成功,1:失败.
 *
 */
int GizLogProvision(const char *openAPIDomain, int openAPISSLPort,
                    const char *appID, const char *uid, const char *token)
{
    int iRet = 1;
    
    if (!gInitedGizLogMutex) {
        GIZ_LOG_ERROR("please call init API first!!!");
        return iRet;
    }
    
    if (!openAPIDomain || !openAPIDomain[0] || openAPISSLPort <= 0 ||
        !appID || !appID[0] || !uid || !uid[0] || !token || !token[0]) {
        GIZ_LOG_ERROR("provision request failed, openAPIDomain %s, openAPISSLPort %d, appID %s, uid %s, token %s",
                      openAPIDomain, openAPISSLPort, appID, uid, token);
        return iRet;
    }
    
    gGizLog.sslPort = openAPISSLPort;
    strncpy(gGizLog.uid, uid, sizeof(gGizLog.uid) - 1);
    strncpy(gGizLog.appID, appID, sizeof(gGizLog.appID) - 1);
    strncpy(gGizLog.token, token, sizeof(gGizLog.token) - 1);
    strncpy(gGizLog.domain, openAPIDomain, sizeof(gGizLog.domain) - 1);
    
    //启动线程
    if (createThread(threadProvision, NULL)) {
        GIZ_LOG_ERROR("createThread threadProvision failed errno %d: %s",
                      errno, strerror(errno));
        return iRet;
    }
    
    return 0;
}

static void logCheckSys(void)
{
    char curPath[LOG_MAX_PATH_LEN] = { 0 };
    struct stat statBuf;
    
    snprintf(curPath, sizeof(curPath), "%s%s.sys", gGizLog.dir, LOG_FILE_NAME);
    if (!gGizLog.fileSys) {
        gGizLog.latestCreatSysLogTimestamp = time(NULL);
        gGizLog.fileSys = fopen(curPath, "a+");  //上次fopen打开失败则再次尝试打开
        if (gGizLog.fileSys) {
            fprintf(gGizLog.fileSys, "%s\n", gSysInfoLogBuf);
            fflush(gGizLog.fileSys);
        }
    }
    stat(curPath, &statBuf);
    //如果检测到当前日志文件大于上限或者已存在的时间超过最大重命名时间，将当前文件重命名为老文件，再新建一个文件存储新日志
    if (statBuf.st_size > LOG_MAX_SYS_FILE_SIZE) {
        logRenameSys();
    }
}

void GizPrintBiz(const char *businessCode, const char *result, const char *format, ...)
{
    size_t index = 0;
    char *pEnd = NULL;
    char *pNewLine = NULL;
    char buf[LOG_MAX_LEN + 1] = { 0 }; //__android_log_print最多只能输出LOG_MAX_LEN(=1024)字节的日志
    char tmpBuf[LOG_MAX_LEN + 1] = { 0 };
    
    snprintf(buf, sizeof(buf), "[APPBIZ][%s][%s][%s]", GizTimeStr(), businessCode, result);
    index = strlen(buf);
    
    //日志格式化
    va_list args;
    va_start(args, format);
    vsnprintf(buf + index, LOG_MAX_LEN - index, format, args);
    va_end(args);
    
    if (buf[LOG_MAX_LEN - 2]) buf[LOG_MAX_LEN - 2] = ']'; //缓存区占满情况下追加结束符
    
    //遇到换行符的情况下将换行符后的内容当做详细日志单独打印(不用[]包)
    strcpy(tmpBuf, buf);
    pNewLine = strchr(buf, '\n');
    if (pNewLine) {
        pEnd = strchr(pNewLine, ']');
        pNewLine[0] = ']';
        pNewLine[1] = '\n';
        memcpy(pNewLine + 2, tmpBuf + (pNewLine - buf) + 1, pEnd - pNewLine - 1);
    }
    
    pthread_mutex_lock(&gMutexGizLog);
    
    //屏幕输出
    if (gGizLog.printLevel >= 1) {
#ifdef __ANDROID__
        __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "%s", buf);
#else
#ifdef TARGET_OS_IPHONE
        NSLog(@"%@", [[NSString alloc] initWithUTF8String:buf]);
#else
        fprintf(stdout, "%s\n", buf);
#endif
#endif
    }
    
    //保存文件
    if (gGizLog.fileBiz) {
        fprintf(gGizLog.fileBiz, "%s\n", buf);
        fflush(gGizLog.fileBiz);
    }
    
    pthread_mutex_unlock(&gMutexGizLog);
}

void GizPrintError(const char *format, ...)
{
    char *pEnd = NULL;
    char *pNewLine = NULL;
    char buf[LOG_MAX_LEN + 1] = { 0 }; //__android_log_print最多只能输出LOG_MAX_LEN(=1024)字节的日志
    char tmpBuf[LOG_MAX_LEN + 1] = { 0 };
    
    //日志格式化
    va_list args;
    va_start(args, format);
    vsnprintf(buf, LOG_MAX_LEN, format, args);
    va_end(args);
    
    if (buf[LOG_MAX_LEN - 2]) buf[LOG_MAX_LEN - 2] = ']'; //缓存区占满情况下追加结束符
    
    //遇到换行符的情况下将换行符后的内容当做详细日志单独打印(不用[]包)
    strcpy(tmpBuf, buf);
    pNewLine = strchr(buf, '\n');
    if (pNewLine) {
        pEnd = strchr(pNewLine, ']');
        pNewLine[0] = ']';
        pNewLine[1] = '\n';
        memcpy(pNewLine + 2, tmpBuf + (pNewLine - buf) + 1, pEnd - pNewLine - 1);
    }
    
    pthread_mutex_lock(&gMutexGizLog);
    
    //屏幕输出
    if (gGizLog.printLevel >= 1) {
#ifdef __ANDROID__
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "%s", buf);
#else
#ifdef TARGET_OS_IPHONE
        NSLog(@"%@", [[NSString alloc] initWithUTF8String:buf]);
#else
        fprintf(stderr, "%s\n", buf);
#endif
#endif
    }
    
    logCheckSys();  //如果日志大小超出上限则删除原文件并重现创建文件
    //保存文件
    if (gGizLog.fileSys) {
        fprintf(gGizLog.fileSys, "%s\n", buf);
        fflush(gGizLog.fileSys);
    }
    
    pthread_mutex_unlock(&gMutexGizLog);
}

void GizPrintDebug(const char *format, ...)
{
    char *pEnd = NULL;
    char *pNewLine = NULL;
    char buf[LOG_MAX_LEN + 1] = { 0 }; //__android_log_print最多只能输出LOG_MAX_LEN(=1024)字节的日志
    char tmpBuf[LOG_MAX_LEN + 1] = { 0 };
    
    //日志格式化
    va_list args;
    va_start(args, format);
    vsnprintf(buf, LOG_MAX_LEN, format, args);
    va_end(args);
    
    if (buf[LOG_MAX_LEN - 2]) buf[LOG_MAX_LEN - 2] = ']'; //缓存区占满情况下追加结束符
    
    //遇到换行符的情况下将换行符后的内容当做详细日志单独打印(不用[]包)
    strcpy(tmpBuf, buf);
    pNewLine = strchr(buf, '\n');
    if (pNewLine) {
        pEnd = strchr(pNewLine, ']');
        pNewLine[0] = ']';
        pNewLine[1] = '\n';
        memcpy(pNewLine + 2, tmpBuf + (pNewLine - buf) + 1, pEnd - pNewLine - 1);
    }
    
    pthread_mutex_lock(&gMutexGizLog);
    
    //屏幕输出
    if (gGizLog.printLevel >= 2) {
#ifdef __ANDROID__
        __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, "%s", buf);
#else
#ifdef TARGET_OS_IPHONE
        NSLog(@"%@", [[NSString alloc] initWithUTF8String:buf]);
#else
        fprintf(stdout, "%s\n", buf);
#endif
#endif
    }
    
    //保存文件
    logCheckSys(); //如果日志大小超出上限则删除原文件并重现创建文件
    if (gGizLog.fileSys) {
        fprintf(gGizLog.fileSys, "%s\n", buf);
        fflush(gGizLog.fileSys);
    }
    
    pthread_mutex_unlock(&gMutexGizLog);
}

/**
 * @brief 打印来至上层的业务日志.
 * @param[in] content- 业务日志内容.
 * @see content内容格式为[BIZ][时间][业务码][执行结果][描述]
 * @see 例:[BIZ][2015-11-24 11:20:49.309][usr_login_req][SUCCESS][用户登录请求]
 *
 */
void GizPrintBizFromUp(const char *content)
{
    int iLen = 0;
    char *pEnd = NULL;
    char *pNewLine = NULL;
    char tmpBuf[LOG_MAX_LEN + 1] = { 0 };
    
    if (!content) {
        GIZ_LOG_ERROR("content from upper layer is null");
        return;
    }
    
    //遇到换行符的情况下将换行符后的内容当做详细日志单独打印(不用[]包)
    iLen = (int)strlen(content);
    if (iLen <= 0 || iLen >= sizeof(tmpBuf)) {
        GIZ_LOG_ERROR("the length(%d) of content from upper layer is unsupported", iLen);
        return;
    }
    strcpy(tmpBuf, content);
    pNewLine = strchr(content, '\n');
    if (pNewLine) {
        pEnd = strchr(pNewLine, ']');
        tmpBuf[pNewLine - content] = ']';
        tmpBuf[pNewLine - content + 1] = '\n';
        memcpy(tmpBuf + (pNewLine - content) + 2, pNewLine + 1, pEnd - pNewLine - 1);
    }
    
    pthread_mutex_lock(&gMutexGizLog);
    
    //屏幕输出
    if (gGizLog.printLevel >= 1) {
#ifdef __ANDROID__
        __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "%s", tmpBuf);
#else
#ifdef TARGET_OS_IPHONE
        NSLog(@"%@", [[NSString alloc] initWithUTF8String:tmpBuf]);
#else
        fprintf(stdout, "%s\n", tmpBuf);
#endif
#endif
    }
    
    //保存文件
    if (gGizLog.fileBiz) {
        fprintf(gGizLog.fileBiz, "%s\n", tmpBuf);
        fflush(gGizLog.fileBiz);
    }
    
    pthread_mutex_unlock(&gMutexGizLog);
}

/**
 * @brief 打印来至上层的错误日志.
 * @param[in] content- 错误日志内容.
 * @see content内容格式为[SYS][ERROR][时间][文件名:行号 函数名][日志体]
 * @see 例:[SYS][ERROR][2015-11-24 11:20:49.309][tool.c:937 connect] [conect 192.168.1.108:12906 failed, connection refused]
 *
 */
void GizPrintErrorFromUp(const char *content)
{
    int iLen = 0;
    char *pEnd = NULL;
    char *pNewLine = NULL;
    char tmpBuf[LOG_MAX_LEN + 1] = { 0 };
    
    if (!content) {
        GIZ_LOG_ERROR("content from upper layer is null");
        return;
    }
    
    //遇到换行符的情况下将换行符后的内容当做详细日志单独打印(不用[]包)
    iLen = (int)strlen(content);
    if (iLen <= 0 || iLen >= sizeof(tmpBuf)) {
        GIZ_LOG_ERROR("the length(%d) of content from upper layer is unsupported", iLen);
        return;
    }
    strcpy(tmpBuf, content);
    pNewLine = strchr(content, '\n');
    if (pNewLine) {
        pEnd = strchr(pNewLine, ']');
        tmpBuf[pNewLine - content] = ']';
        tmpBuf[pNewLine - content + 1] = '\n';
        memcpy(tmpBuf + (pNewLine - content) + 2, pNewLine + 1, pEnd - pNewLine - 1);
    }
    
    pthread_mutex_lock(&gMutexGizLog);
    
    //屏幕输出
    if (gGizLog.printLevel >= 1) {
#ifdef __ANDROID__
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "%s", tmpBuf);
#else
#ifdef TARGET_OS_IPHONE
        NSLog(@"%@", [[NSString alloc] initWithUTF8String:tmpBuf]);
#else
        fprintf(stderr, "%s\n", tmpBuf);
#endif
#endif
    }
    
    logCheckSys();  //如果日志大小超出上限则删除原文件并重现创建文件
    //保存文件
    if (gGizLog.fileSys) {
        fprintf(gGizLog.fileSys, "%s\n", tmpBuf);
        fflush(gGizLog.fileSys);
    }
    
    pthread_mutex_unlock(&gMutexGizLog);
}

/**
 * @brief 打印来至上层的调试日志.
 * @param[in] content- 调试日志内容.
 * @see content内容格式为[SYS][DEBUG][时间][文件名:行号 函数名][日志体]
 * @see 例:[SYS][DEBUG][2015-11-24 11:20:49.309][tool.c:937 connect] [conect 192.168.1.108:12906 success, fd 127]
 *
 */
void GizPrintDebugFromUp(const char *content)
{
    int iLen = 0;
    char *pEnd = NULL;
    char *pNewLine = NULL;
    char tmpBuf[LOG_MAX_LEN + 1] = { 0 };
    
    if (!content) {
        GIZ_LOG_ERROR("content from upper layer is null");
        return;
    }
    
    //遇到换行符的情况下将换行符后的内容当做详细日志单独打印(不用[]包)
    iLen = (int)strlen(content);
    if (iLen <= 0 || iLen >= sizeof(tmpBuf)) {
        GIZ_LOG_ERROR("the length(%d) of content from upper layer is unsupported", iLen);
        return;
    }
    strcpy(tmpBuf, content);
    pNewLine = strchr(content, '\n');
    if (pNewLine) {
        pEnd = strchr(pNewLine, ']');
        tmpBuf[pNewLine - content] = ']';
        tmpBuf[pNewLine - content + 1] = '\n';
        memcpy(tmpBuf + (pNewLine - content) + 2, pNewLine + 1, pEnd - pNewLine - 1);
    }
    
    pthread_mutex_lock(&gMutexGizLog);
    
    //屏幕输出
    if (gGizLog.printLevel >= 2) {
#ifdef __ANDROID__
        __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, "%s", tmpBuf);
#else
#ifdef TARGET_OS_IPHONE
        NSLog(@"%@", [[NSString alloc] initWithUTF8String:tmpBuf]);
#else
        fprintf(stdout, "%s\n", tmpBuf);
#endif
#endif
    }
    
    logCheckSys();  //如果日志大小超出上限则删除原文件并重现创建文件
    //保存文件
    if (gGizLog.fileSys) {
        fprintf(gGizLog.fileSys, "%s\n", tmpBuf);
        fflush(gGizLog.fileSys);
    }
    
    pthread_mutex_unlock(&gMutexGizLog);
}

char *GizTimeStr(void)
{
    time_t tvSec = 0;
    struct timeval now;
    struct tm *ptm = NULL;
    char buf[32] = { 0 };
    
    gettimeofday(&now, NULL);
    tvSec = now.tv_sec;
    ptm = localtime(&tvSec);
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", ptm);
    snprintf(gTimeStr, sizeof(gTimeStr), "%s.%03d", buf, (int )(now.tv_usec / 1000));
    
    return gTimeStr;
}

void GizClose(int fd, const char *file, int line, const char *function)
{
    if (fd > 0) {
        close(fd);
        GIZ_LOG_DEBUG("closed fd %d in <%s:%d %s> success", fd, file, line, function);
    }
}

#ifdef __cplusplus
}
#endif
