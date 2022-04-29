---
title: '从linux内核函数角度,JAVA角度聊IO发展史,并叙述netty'
date: 2021-06-24 11:52:45
categories: 架构
tags:
    - IO模型
    - 高并发
    - netty
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/hexo.jpg
---

# 从linux内核函数角度,JAVA角度聊IO发展史,并叙述netty

## 前言

前些天一直在看netty,感觉网络博客少有从内核函数的角度直接剖析io到nio的发展,并和java的netty框架结合起来的,导致很多人对netty的概念仅仅停留在抽象的角度,就损失很多细节方面的东西以及对io模型的整体把控,所以写了这一篇博客,希望读者读后能发现新的东西,以及有一个系统的知识,当然因为时间问题,本篇博客会写的简单一些,后期可能会写出更加细节系统化的系列.

## 先聊linux

<!--more-->

我们知道java是一款虚拟机,它是根据不同的操作系统虚拟化出来的一层代码(所以我们的jdk会划分windows版,linux版,mac版等等),我们只讨论linux版,因为windows,mac是闭源的,看不到源代码,也就无从聊起机制细节是什么样的

### 一些概念前提

**文件描述符**:   我们知道linux当中有一切皆文件的说法,访问磁盘的文件是文件,进程是文件,socket网络也是一个文件,我们可以通过lsof 列出进程,用户打开的文件,就像下面这样(列出某进程打开的文件)

```bash
lemcoden@unbuntu:~/develop/my-bigdata$ lsof -p 43587 | less
COMMAND   PID     USER   FD      TYPE             DEVICE  SIZE/OFF     NODE NAME
chrome  43587 lemcoden    0r      CHR                1,3       0t0        6 /dev/null
chrome  43587 lemcoden    1w     FIFO               0,13       0t0   418082 pipe
chrome  43587 lemcoden    2w     FIFO               0,13       0t0   418084 pipe
chrome  43587 lemcoden    3u  a_inode               0,14         0    11473 [eventpoll]
chrome  43587 lemcoden    4u     unix 0x0000000000000000       0t0   418088 type=SEQPACKET
chrome  43587 lemcoden    5r      REG              259,3  10413488 11272442 /opt/google/chrome/icudtl.dat
chrome  43587 lemcoden    6r      REG              259,3    165675 11272541 /opt/google/chrome/v8_context_snapshot.bin
```

这其中第一行标题一个FD(FileDescrption)的列,意思就是文件描述符,既然在linux当中一切皆文件,那必然有它被访问的入口,这个就是linux的文件描述符,什么?你不熟?相信大家这条命令总见过吧

```scala
lemcoden@unbuntu:nohup xxxxx.proccess 2>&1 > /dev/null &
```

而2>&1我们经常说它是错误输出重定向到标准输出,而这个2和1就是我们FD的名字,对应我们上面某进程的1和2,后面的r,w,u分别代表着只读,只写,即可读又可写,这就和我们标准输入,标准输出对应上了

**虚拟内存:**   这个笔者也无奈直接讲个故事吧,很久很久之前的第一代操作系统像Dos这样的,因为硬件资源少的一个操作系统上只能运行一个程序,所以对于这个正在运行的程序来说,它可以占掉所有的内存计算资源.

但之后呢,硬件资源上来的,我的算力明显提升,一个操作系统上只运行一个程序有点得不偿失,于是大家就想着开发多任务的操作系统,但是多任务的操作系统有两个问题,

1. 就是内存的划分问题,如果多个程序可以资源使用内存,程序A和程序B相互无通信却选择了同一块内存区域读写怎么办?即内存区域管理混乱问题
2. 多任务的操作系统,程序和操作系统有了明显的分工,操作系统负责维护硬件,像网卡,磁盘,CPU等,而此时对于操作系统来说,程序直接访问硬件相当于夺取操作系统控制权,这是个安全问题

第一个问题是就是通过虚拟内存的方式解决的,我先把系统运行的内存和程序运行的内存隔离开来,当程序运行时,向系统申请内存,系统会给程序划定一块内存,这块内存就叫做虚拟内存,为什么是虚拟的呢?

是这样的,首先真的物理内存,内存第0号开始先是系统引导(这里不确定，这么说仅仅是为了便于理解,后期会更加详细研究),再是系统运行的内存,之后才是第一个要运行的用户程序的内存,然后是第二个用户程序以此类推,那么对用户程序来说它的内存地址绝对不是从0开始的,但是系统会有一系列的复杂转址过程,将物理地址转成对用户程序来说是从0开始的虚拟地址,所以这块内存就叫做虚拟内存

然后我们运行在虚拟内存当中的用户程序我们称它处于用户态,虚拟内存叫做用户空间

运行在物理内存当中的操作系统我们称它处于内核态,物理内存叫做内核空间

**中断**:   上述概念了解明白之后,我们还有一个问题,假如我用户程序想访问网卡,磁盘或者其他只有系统内核才能访问的硬件该怎么办? 首先有个大前提,就是我已经把系统内核和用户程序隔离开了,用户程序无权读写系统内核的内存,那怎么通知操作系统呢?

答案是使用中断,老版的中断是通过自陷异常通知的系统内核,我们java的程序员可以理解为抛出一个异常,对,抛出一个异常,系统捕获到了,知道哦~~~~用户程序要用硬件资源搞事情,搞什么事情呢?用户程序会写在CPU的寄存器上,然后系统内核会保存用户程序现在的执行状态,然后挂起,专心在内核态把用户程序要搞的事搞完,然后回来把用户程序通过保存的执行状态唤醒并运行用户程序,所以大家就经常说

**用户态和内核态的切换非常耗费资源**

**linux系统调用函数**:   这个百度一下就会搜到相关的系统调用函数列表,这里我仅仅是解释一下系统调用函数是什么,其实它就是上面中断的外包装,也就是说系统调用函数基本都使用中断来实现,但是每个函数各有各的功能,有linux系统的同学可以安装一个man命令,这是一个可以查看命令文档的程序,我们先用man命令看一下man命令的文档

```bash
lemcoden@unbuntu:~/$ man man
MAN(1)                                                                  手册分页显示工具                                                                 MAN(1)

名称
       man - an interface to the system reference manuals

概述
       man [man options] [[section] page ...] ...
       man -k [apropos options] regexp ...
       man -K [man options] [section] term ...
       man -f [whatis 选项] 页 ...
       man -l [man options] file ...
       man -w|-W [man options] page ...
 描述
       man  is  the system's manual pager.  Each page argument given to man is normally the name of a program, utility or function.  The manual page associated
       with each of these arguments is then found and displayed.  A section, if provided, will direct man to look only in that  section  of  the  manual.   The
       default  action  is to search in all of the available sections following a pre-defined order (see DEFAULTS), and to show only the first page found, even
       if page exists in several sections.

       下表显示了手册的 章节 号及其包含的手册页类型。

       1   可执行程序或 shell 命令
       2   系统调用(内核提供的函数)
       3   库调用(程序库中的函数)
       4   特殊文件(通常位于 /dev)
       5   File formats and conventions, e.g. /etc/passwd
       6   游戏
       7   杂项(包括宏包和规范，如 man(7)，groff(7))
       8   系统管理命令(通常只针对 root 用户)
       9   内核例程 [非标准

       一个手册 页面 包含若干个小节。
```

重点看描述当中,2 表示的是系统调用的函数,也就是说,我们可以通过man 2 系统调用函数名,查看系统调用的文档,比如 socket

```bash
lemcoden@unbuntu:~/develop/my-bigdata$ man 2 socket
SOCKET(2)                                                          Linux Programmer's Manual                                                          SOCKET(2)

NAME
       socket - create an endpoint for communication

SYNOPSIS
       #include <sys/types.h>          /* See NOTES */
       #include <sys/socket.h>

       int socket(int domain, int type, int protocol);

DESCRIPTION
       socket() creates an endpoint for communication and returns a file descriptor that refers to that endpoint.  The file descriptor returned by a successful
       call will be the lowest-numbered file descriptor not currently open for the process.

       The domain argument specifies a communication domain; this selects the protocol family which will be used for communication.  These families are defined
       in <sys/socket.h>.  The formats currently understood by the Linux kernel include:

       Name         Purpose                                    Man page
       AF_UNIX      Local communication                        unix(7)
       AF_LOCAL     Synonym for AF_UNIX
       AF_INET      IPv4 Internet protocols                    ip(7)
       AF_AX25      Amateur radio AX.25 protocol               ax25(4)
..........
```

## 内核角度的IO模型

我们都知道IO分为BIO,NIO,AIO

分别表示同步阻塞模型,同步非阻塞模型,异步非阻塞模型(异步模型只有windows系统有)

我们从后端应用的开发历史来看这几个模型是怎么一步步发展过来的

### BIO(同步阻塞模型)

我们知道java都是调用linux的系统调用函数来实现IO模型的,那我们从内核函数来讲

首先第一个函数socket

```bash
lemcoden@unbuntu:~$ man 2 socket
DESCRIPTION
       socket()  creates  an endpoint for communication and returns a file de‐
       scriptor that refers to that endpoint.  The file descriptor returned by
       a  successful call will be the lowest-numbered file descriptor not cur‐
       rently open for the process.
```

这个函数意思是在网卡上开辟一块区域用于做连接的绑定和数据的传输,它会返回一个文件描述符指向这块空区域,为了方便后面区分,我们叫它fd3

然后是 函数bind

```bash
lemcoden@unbuntu:~$ man 2 bind
DESCRIPTION 描述
       bind  为套接字  sockfd  指定本地地址 my_addr.  my_addr 的长度为 addrlen
       (字节).传统的叫法是给一个套接字分配一个名字.  当使用 socket(2),  函数创
       建一个套接字时,它存在于一个地址空间(地址族), 但还没有给它分配一个名字

       一般来说在使用 SOCK_STREAM 套接字建立连接之前总要使用 bind 为其分配一个
       本地地址.参见 accept(2)).
```

我们拿到网卡的文件描述符之后,将fd3传给bind,并输入本地的ip地址以及端口号,表示我的文件描述符fd3绑定了本地地址某某端口号

之后是 函数listen

```bash
lemcoden@unbuntu:~$ man 2 listen
DESCRIPTION 描述
       在接收连接之前,首先要使用 socket(2) 创建一个套接字,然后调用 listen 使其
       能够自动接收到来的连接并且为连接队列指定一个长度限制.    之后就可以使用
       accept(2)    接收连接.     listen    调用仅适用于    SOCK_STREAM   或者
       SOCK_SEQPACKET 类型的套接字.

       参数 backlog  指定未完成连接队列的最大长度.如果一个连接请求到达时未完成
       连接 队列已满,那么客户端将接收到错误 ECONNREFUSED.  或者,如果下层协议支
       持重发,那么这个连接请求将被忽略,这样客户端 在重试的时候就有成功的机会.
```

然后再将持有的文件描述符交给listen函数,让文件描述符fd3可以接收它绑定端口相关的连接

之后是 函数accept

```bash
DESCRIPTION 描述
       accept   函数用于基于连接的套接字   (SOCK_STREAM,   SOCK_SEQPACKET   和
       SOCK_RDM).  它从未完成连接队列中取出第一个连接请求,创建一个和参数 s  属
       性相同的连接套接字,并为这个套接字分配一个文件描述符, 然后以这个描述符返
       回.新创建的描述符不再处于倾听状态.原 套接字 s 不受此调用的影响.注意任意
       一个文件描述符标志  (任何可以被 fcntl以参数 F_SETFL 设置的值,比如非阻塞
       式或者异步状态)不会被 accept.  所继承.
```

这个accpet函数需要额外重点说明,首先它是一个阻塞函数,它也接收我们的fd3,它的意思是如果来了一个新的连接,它会给新的连接一个文件描述符,并且返回,如果没有,阻塞当前函数,这个是与每个客户端建立的连接的文件描述符,因为不止有一个客户端连接到本地,所以在java的IO包中,会在外层加一个循环,不断轮询调用此函数返回与客户端建立的连接,我们把新的连接的文件描述命名为fd4,fd5,fd6..............

之后是 函数 recv

```bash
lemcoden@unbuntu:~$ man 2 recv
DESCRIPTION
       The  recv(),  recvfrom(),  and recvmsg() calls are used to receive mes‐
       sages from a socket.  They may be used to receive data on both  connec‐
       tionless  and  connection-oriented  sockets.  This page first describes
       common features of all three system calls, and then describes the  dif‐
       ferences between the calls.
```

我们拿到新的客户端连接之后,再交给recv函数,recv函数会专门返回当前连接客户端所传输的数据,这个方法也是阻塞的.

我们再回顾一下accept函数和recv函数,accpet函数负责返回连接,recv负责获取当前连接的数据,

而再java IO底层,每获取一个连接,就会新开一个线程来负责这个连接数据传输即调用recv方法,为什么?

因为recv方法是阻塞的,如果在一个线程里面轮询所有连接调用recv,一旦其中一个客户端没数据,那么recv方法就会阻塞在那里,那么其他所有的连接就得一直等待排在后面.

那么问题来了,如果我有一万个连接要进来,那么我还start 一万个线程?

我们首先分析一下,一般一个空线程需要占用内存大约1M的资源,那么一万个线程相当于10G的内存资源,也就是说,我还没传输数据呢,光空线程就占用了10G资源

那再说一下,线程切换的开销,假如我的服务器CPU 10核,那么开启超过10个线程就需要线程来回切换,那一万个线程就需要平均1000个线程在一个核上来回切换,这个成本很巨大,不可忽略

### NIO(同步非阻塞IO)

基于上面的问题,所以才有了我们的非阻塞的IO

非阻塞IO非常简单,在调用我们刚刚的socket函数的时候.只要传入一个SOCK_NONBLOCK标志位就可以,然后accept以及recv函数就会变成非阻塞的函数,如果调用没有连接和数据,他们就会返回-1

那么我们的线程布局就不一样了,

以前我们是主线程调用accept函数返回连接,然后每个连接开一个线程

现在我们是开一个线程专门做连接的维护,然后开一个线程池专门拉取数据,线程池中每一个线程持有多个连接,可以轮询获取多个连接的数据

这样就不用但心我们的线程过多所导致的内存开销大,响应极慢的问题

### NIO多路复用器 —> select/poll函数

不过旧的问题解决了,又产生了新的问题,上面的NIO模型对java调用来说没问题,但是对linux来说还会有点慢,我们细扣一下细节,我们一个线程负责多个连接的数据传输,每连接每次拉取或者写入数据都需要遍历做recv的系统调用,而我们之前说过,只要调用系统函数,就会发生用户态和内核态的切换这个很耗费资源,假如有N个连接,遍历调用的时间复杂度是0(n),这0(n)当中又有很多空数据连接是浪费掉的.

那么我们怎么才能减少recv函数的调用次数呢?

这时候又有两个新的内核函数横空出世,那就是select/poll 系统调用,

```bash
lemcoden@unbuntu:~$ man 2 select
NAME
       select, pselect, FD_CLR, FD_ISSET, FD_SET, FD_ZERO - synchronous I/O multiplexing
DESCRIPTION
       select()  and pselect() allow a program to monitor multiple file descriptors, waiting until one or
       more of the file descriptors become "ready" for some class of I/O operation  (e.g.,  input  possi‐
       ble).   A file descriptor is considered ready if it is possible to perform a corresponding I/O op‐
       eration (e.g., read(2), or a sufficiently small write(2)) without blocking.

lemcoden@unbuntu:~$ man 2 poll
DESCRIPTION
       poll()  performs a similar task to select(2): it waits for one of a set of file descriptors to be‐
       come ready to perform I/O.

       The set of file descriptors to be monitored is specified in the fds argument, which is an array of
......
```

select与poll的函数调用非常相似,都是将一组文件描述符作为参数,但是唯一的不同点在于select的文件描述符组有1024这个长度的限制,但是poll没有

说一下他们俩的主要功能,就是输入一组连接的文件描述符,然后会返回有数据的文件描述符数量,并在文件描述符组中标记这些有数据的FD

所以调用accept之后,会把返回的文件描述符用一个集合结构存起来,并调用select

java在调用select之后,会遍历被select标记过的文件描述符组,再通过FD_ISSET这个函数来判断文件描述符是否被标记,被标记了,再执行recv方法,这样就避免了大量空数据连接使用系统调用的问题

恩,好像还有一个epoll没聊,从上面一路看下来的同学都知道,如果出现新的技术肯定是老的技术有某些问题,那么select/poll 多路复用器有什么问题呢?

首先select/poll 内核函数在我们传入fd组之后,它会遍历fd组,找出哪些fd有数据存储着,当然在内核中遍历的确比多次调用系统函数的遍历要快很多,

1. 但还是要触发一个全量复杂度的遍历,
2. 并且select外避免不了多次重复传入fd组,每次传入内核都要重新开辟空间用于存放

### NIO 多路复用器—> epoll函数

epoll表示的是一组函数,分别是epoll_create,epoll_ctl和epoll_wait

这里笔者就不再给出man命令介绍了,直接说怎么用以及它内在的机制是什么样的

首先调用epoll_create,epoll_create会在内核空间当中开辟一块儿内存,使用红黑树结构,并且返回标识这块内存的FD,我们都叫它EPFD,即epoll函数的空间的文件描述符

然后我们将这个EPFD传入到epoll_ctl(control缩写)当中,epoll_ctl还有两个参数,一个是连接的FD,一个是我们具体的操作类型,操作类型有三种EPOLL_CTL_ADD,EPOLL_CTL_MOD,EPOLL_CTL_DEL(添加,修改,删除)我们主要是使用的添加操作,即将我们连接的FD添加到刚刚创建的那块红黑数的内存区域当中

然后epoll这个系统调用对中断程序进行了扩展,当我们的数据通过网卡copy到FD的缓存时,中断程序会自动把处于红黑树的FD移动到另一个epoll_wait函数所使用的链表当中

最后,调用epoll_wait函数,将它下面的FD链表全部返回

然后我们就可以遍历链表,挨个挨个recv数据了

这样子就规避了,要不断重复开辟内核空间的问题,并且全程无遍历

## 从JAVA层面看IO模型

如果前面的linux看能坚持看完的话,到了JAVA这里就会感觉有好多东西能够对应上,比如文件描述符和channel,多路复用的select/poll/epoll函数 与JAVA的selector多路复用器,以及同名的accept方法函数等等

### BIO模型

```java
public class SocketBIO {
    public static void main(String[] args) throws Exception {
        ServerSocket server = new ServerSocket(9090,20);
        System.out.println("step1: new ServerSocket(9090) ");
        while (true) {
            Socket client = server.accept();  //阻塞1
            System.out.println("step2:client\t" + client.getPort());
            new Thread(new Runnable(){
                public void run() {
                    InputStream in = null;
                    try {
                        in = client.getInputStream();
                        BufferedReader reader = new BufferedReader(new InputStreamReader(in));
                        while(true){
                            String dataline = reader.readLine(); //阻塞2

                            if(null != dataline){
                                System.out.println(dataline);
                            }else{
                                client.close();
                                break;
                            }
                        }
                        System.out.println("客户端断开");

                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            }).start();

        }
    }
}
```

了解清楚了linux系统调用后，BIO的java阻塞代码就很容易理解了，ServerSocket封装的socket,bind,listen系统调用

accept方法封装的accept系统调用

client里面有新产生的连接，即新的文件描述符，每产生一个新的连接，就start一个线程来运行单个连接的数据的收发

### NIO模型

```java
public class SocketNIO {

    //  what   why  how
    public static void main(String[] args) throws Exception {

        LinkedList<SocketChannel> clients = new LinkedList<>();
        ServerSocketChannel ss = ServerSocketChannel.open();  //服务端开启监听：接受客户端
        ss.bind(new InetSocketAddress(9090));
        ss.configureBlocking(false); //重点  OS  NONBLOCKING!!!  //只让接受客户端  不阻塞
        while (true) {
            //接受客户端的连接
            Thread.sleep(1000);
            SocketChannel client = ss.accept(); //不会阻塞？  -1 NULL
            //accept  调用内核了：1，没有客户端连接进来，返回值？在BIO 的时候一直卡着，但是在NIO ，不卡着，返回-1，NULL
            //如果来客户端的连接，accept 返回的是这个客户端的fd  5，client  object
            //NONBLOCKING 就是代码能往下走了，只不过有不同的情况

            if (client == null) {
             //   System.out.println("null.....");
            } else {
                client.configureBlocking(false); //重点  socket（服务端的listen socket<连接请求三次握手后，往我这里扔，我去通过accept 得到  连接的socket>，连接socket<连接后的数据读写使用的> ）
                int port = client.socket().getPort();
                System.out.println("client..port: " + port);
                clients.add(client);
            }
            ByteBuffer buffer = ByteBuffer.allocateDirect(4096);  //可以在堆里   堆外
            //遍历已经链接进来的客户端能不能读写数据
            for (SocketChannel c : clients) {  
                int num = c.read(buffer); //不会阻塞
                if (num > 0) {
                    buffer.flip();
                    byte[] aaa = new byte[buffer.limit()];
                    buffer.get(aaa);
                    String b = new String(aaa);
                    System.out.println(c.socket().getPort() + " : " + b);
                    buffer.clear();
                }

            }
        }
    }

}
```

到了NIO时代也一样,仅仅是将ServerSocket对象变成ServerSocketChannle对象,读写方式由传统的IO流变成了既可读又可写的Channel(实际上底层还是文件描述符),

有个配置项configureBlocking(false),这其实就是底层的SOCK_NONBLOCK,

新的ByteBuffer缓冲区,可以在堆外内存分配数据,这里说一下所谓的堆外内存或者直接内存其实就是用户空间的内存,还有一种内存可以通过内核函数mmap分配,这个是内核空间和用户空间的共享内存,用户程序访问mmap的这块内存,不会产生用户态到内核态的切换.所以请求速度内存的请求速度排列大致如下

mmap > 堆外内存/直接内存 > 堆内内存

### 多路复用器NIO

```java
public class SocketMultiplexingSingleThreadv1 {

    private ServerSocketChannel server = null;
    private Selector selector = null;   //linux 多路复用器（select poll    epoll kqueue） nginx  event{}
    int port = 9090;

    public void initServer() {
        try {
            server = ServerSocketChannel.open();
            server.configureBlocking(false);
            server.bind(new InetSocketAddress(port));
            //如果在epoll模型下，open--》  epoll_create -> fd3
            selector = Selector.open();  //  select  poll  *epoll  优先选择：epoll  但是可以 -D修正

            //server 约等于 listen状态的 fd4
            /*
            register
            如果：
            select，poll：jvm里开辟一个数组 fd4 放进去
            epoll：  epoll_ctl(fd3,ADD,fd4,EPOLLIN
             */
            server.register(selector, SelectionKey.OP_ACCEPT);

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void start() {
        initServer();
        System.out.println("服务器启动了。。。。。");
        try {
            while (true) {  //死循环

                Set<SelectionKey> keys = selector.keys();
                System.out.println(keys.size()+"   size");

                //1,调用多路复用器(select,poll  or  epoll  (epoll_wait))
                /*
                select()是啥意思：
                1，select，poll  其实  内核的select（fd4）  poll(fd4)
                2，epoll：  其实 内核的 epoll_wait()
                *, 参数可以带时间：没有时间，0  ：  阻塞，有时间设置一个超时
                selector.wakeup()  结果返回0

                懒加载：
                其实再触碰到selector.select()调用的时候触发了epoll_ctl的调用

                 */
                while (selector.select() > 0) {
                    Set<SelectionKey> selectionKeys = selector.selectedKeys();  //返回的有状态的fd集合
                    Iterator<SelectionKey> iter = selectionKeys.iterator();
                    //so，管你啥多路复用器，你呀只能给我状态，我还得一个一个的去处理他们的R/W。同步好辛苦！！！！！！！！
                    //  NIO  自己对着每一个fd调用系统调用，浪费资源，那么你看，这里是不是调用了一次select方法，知道具体的那些可以R/W了？
                    //幕兰，是不是很省力？
                    //我前边可以强调过，socket：  listen   通信 R/W
                    while (iter.hasNext()) {
                        SelectionKey key = iter.next();
                        iter.remove(); //set  不移除会重复循环处理
                        if (key.isAcceptable()) {
                            //看代码的时候，这里是重点，如果要去接受一个新的连接
                            //语义上，accept接受连接且返回新连接的FD对吧？
                            //那新的FD怎么办？
                            //select，poll，因为他们内核没有空间，那么在jvm中保存和前边的fd4那个listen的一起
                            //epoll： 我们希望通过epoll_ctl把新的客户端fd注册到内核空间
                            acceptHandler(key);
                        } else if (key.isReadable()) {
                            readHandler(key);  //连read 还有 write都处理了
                            //在当前线程，这个方法可能会阻塞  ，如果阻塞了十年，其他的IO早就没电了。。。
                            //所以，为什么提出了 IO THREADS
                            //redis  是不是用了epoll，redis是不是有个io threads的概念 ，redis是不是单线程的
                            //tomcat 8,9  异步的处理方式  IO  和   处理上  解耦
                        }
                    }
                }
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void acceptHandler(SelectionKey key) {
        try {
            ServerSocketChannel ssc = (ServerSocketChannel) key.channel();
            SocketChannel client = ssc.accept(); //来啦，目的是调用accept接受客户端  fd7
            client.configureBlocking(false);

            ByteBuffer buffer = ByteBuffer.allocate(8192);  //前边讲过了

            // 0.0  我类个去
            //你看，调用了register
            /*
            select，poll：jvm里开辟一个数组 fd7 放进去
            epoll：  epoll_ctl(fd3,ADD,fd7,EPOLLIN
             */
            client.register(selector, SelectionKey.OP_READ, buffer);
            System.out.println("-------------------------------------------");
            System.out.println("新客户端：" + client.getRemoteAddress());
            System.out.println("-------------------------------------------");

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void readHandler(SelectionKey key) {
        SocketChannel client = (SocketChannel) key.channel();
        ByteBuffer buffer = (ByteBuffer) key.attachment();
        buffer.clear();
        int read = 0;
        try {
            while (true) {
                read = client.read(buffer);
                if (read > 0) {
                    buffer.flip();
                    while (buffer.hasRemaining()) {
                        client.write(buffer);
                    }
                    buffer.clear();
                } else if (read == 0) {
                    break;
                } else {
                    client.close();
                    break;
                }
            }
        } catch (IOException e) {
            e.printStackTrace();

        }
    }

    public static void main(String[] args) {
        SocketMultiplexingSingleThreadv1 service = new SocketMultiplexingSingleThreadv1();
        service.start();
    }
}
```

到了多路复用器,事情突然就变得很复杂,主要JAVA一个Selector对象将accept,recv函数以及文件描述符Channel同时封装起来了,导致后面需要分逻辑处理

可能是因为java是个抽象虚拟层,需要同时兼容windows,linux和Mac,而且windows的多路复用函数只有select,所以我们调用的API它必须高度抽象.才导致封装的东西调用起来比较难受,所以之后netty才火起来,因为Reactor模型很容易理解,封装出来的API调用简单.

## Reactor模型Netty

```java
	/**
 * 服务器入口类
 */
public class ServerMain {

    private static final Logger LOGGER = LoggerFactory.getLogger(ServerMain.class);
    /**
     * 日志对象
     * @param args
     */

    public static void main(String[] args) {

        EventLoopGroup bossEventGroup = new NioEventLoopGroup();
        EventLoopGroup workerGroup = new NioEventLoopGroup();

        ServerBootstrap b = new ServerBootstrap();
        b.group(bossEventGroup,workerGroup);
        b.channel(NioServerSocketChannel.class);
        b.childHandler(new ChannelInitializer<SocketChannel>() {
            @Override
            protected void initChannel(SocketChannel channel) throws Exception {
                channel.pipeline().addLast(
                        new HttpServerCodec(),
                        new HttpObjectAggregator(65535),
                        new WebSocketServerProtocolHandler("/websocket"),
                        new GameMsgHandler()
                );
            }
        });

        try {
            ChannelFuture f = b.bind(12138).sync();
            if (f.isSuccess()){
                LOGGER.info("服务器启动成功");
            }
            //等待服务器信道关闭
            *//也就是不要立即退出应用程序,让应用程序可以一直提供服务*
            f.channel().closeFuture().sync();
        } catch (InterruptedException e) {
            LOGGER.error("服务器启动失败",e);
        }
    }
}
```

与java原生的NIO比起来，netty的代码看起来就简洁很多了

(一项技术能流行起来的两个因素,它的调用特别简单,它的实现技术很复杂且都有利于它的目的)

首先有两个同类型对象EventLoopGroup，LoopGroup这个名字首先让人联想到的就是无限轮询的线程                      池，的确LoopGroup对象本质上就是一个线程池，他的构造体可以定义线程数量，线程池的线程中封装了java原生NIO的逻辑

往回倒一倒，两个同类对象都被ServerBootstrap注册，一个负责建立并返回新连接，一个根据新连接数量建立适量的线程，线程在管理的连接中读写数据

而NioServerSocketChannel就是可读写的文件描述符的封装

然后childHandler方法，是为了帮助我们在处理数据的线程中预埋自己的逻辑，通过addLast方法,添加Handler类对象实现,并且预埋逻辑在pipeline中的handlers有两个方向,一个接收的pipeline,一个是响应的pipeline.分别继承自ChannelInboundHandler,ChannelOutboundHandler

## Http协议对比

讲完IO,NIO到多路复用器到上层的Reactor模型之后，我们再和http协议对比一下，说一下两者的试用场景。

http有两个特点，一个是无状态的连接，一个是严格的字符请求报文格式。

什么是无状态？就是没有记忆，客户端请求一次，服务端建立连接，响应一次，这次的连接就直接弃用了，它没有会话连接，长连接这么一个概念。

字符请求报文格式，

请求必须包含请求行，请求头，请求体

响应必须包含响应行，响应头，响应体

而且请求响应必须都是字符型的

这样协议适合一般的网页前端，移动应用端的场景，因为这样的场景下用户请求频率比较稀疏

但是遇到网游或者推送场景就不行了，首先游戏后端用户操作请求特别的密集，如果使用字符型的报文格式，短时间数据量会很巨大，网卡很容易就撑爆卡在那里，只能自己用字节码定义请求格式,而且网游的动作都是定死的,再用protoBuf,thrift等进行编码,可以把每次传输的数据格式压缩到十几个字节的水平,不像http一次请求光请求头就占用上百字节.

并且游戏客户端需要后端推送其他用户的信息，才能达到交互的目的，而推送功能的前提就是建立长连接。

## 后期会补上的知识

我说,NioEventLoopGroup本质上是一个线程池,我本以为它其中的执行线程Executor对象继承自Runnable,但是粗略的看过源码之后才发现它其实是JUC当中的类,也就是jdk原生提供的高并发的调用,所以笔者会在后期,出几篇netty源码分析并且,再深入研究一下JUC的包
