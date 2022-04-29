---
title: spark源码分析资源层过渡计算层-2
date: 2021-06-06 14:59:21
tags:
    - 大数据计算框架
    - 分布式
cover_picture: https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/cover_picture/spark.png
---

## 书接上文

上次源码分析之后,笔者自己通读了一遍,发现有些地方,有些问题没有说明白,所以就上篇博客遗留的问题做一个回答

### 序列化器在哪用到了?

上此聊到RPCEnv对象创建的时候,会创建序列化器,2.3.4版本使用Java默认的序列化器,然后在哪里用呢?

这里先给出<font color= #FFA500>NettyRpcHandler recive</font>的代码(怎么找到的?请看上篇博客)

```scala
  override def receive(
      client: TransportClient,
→       message: ByteBuffer,
      callback: RpcResponseCallback): Unit = {
→   val messageToDispatch = internalReceive(client, message)
    dispatcher.postRemoteMessage(messageToDispatch, callback)
  }
```

我们看到message原本是字节缓存,通过<font color= #FFA500>internalReceive</font>方法组装成<font color= #FFA500>RequestMessage</font>对象

<!--more-->

那再进internalRecceive方法

```scala
 private def internalReceive(client: TransportClient, message: ByteBuffer): RequestMessage = {
    val addr = client.getChannel().remoteAddress().asInstanceOf[InetSocketAddress]
    assert(addr != null)
...
    val clientAddr = RpcAddress(addr.getHostString, addr.getPort)
→   val requestMessage = RequestMessage(nettyEnv, client, message)
...
      requestMessage
    }
  }
```

再进<font color= #FFA500>RequestMessage</font>

```scala
 def apply(nettyEnv: NettyRpcEnv, client: TransportClient, bytes: ByteBuffer): RequestMessage = {
    val bis = new ByteBufferInputStream(bytes)
    val in = new DataInputStream(bis)
    try {
      val senderAddress = readRpcAddress(in)
      val endpointAddress = RpcEndpointAddress(readRpcAddress(in), in.readUTF())
      val ref = new NettyRpcEndpointRef(nettyEnv.conf, endpointAddress, nettyEnv)
      ref.client = client
      new RequestMessage(
        senderAddress,
        ref,
        // The remaining bytes in `bytes` are the message content.
        nettyEnv.deserialize(client, bytes))
    } finally {
      in.close()
    }
  }
```

我们会发现字节缓存前面的部分会通过缓冲流把开头的地址读取出来,然后剩下的部分就是消息内容,这个就是数据报文的设计,有兴趣的同学可以细研究一下.

通过<font color= #FFA500>nettyEnv.deserialize</font>反序列化为对象,而反序列化的方法内部

```scala

  private[netty] def deserialize[T: ClassTag](client: TransportClient, bytes: ByteBuffer): T = {
    NettyRpcEnv.currentClient.withValue(client) {
      deserialize { () =>
        javaSerializerInstance.deserialize[T](bytes)
      }
    }
  }
```

就是通过java序列化器进行反序列化的.

### 一个细节阐明

上次我们说代码有send,ask,recive,reciveAndReply这样的消息投递规则,但是有一点需要明确,send方法对应recive方法,ask方法reciveAndReply方法,也就是是说,他们方法是一一对应的,并不是胡乱调用的,具体可以看inbox的proccess方法,其中rpcMessage类型和oneWayMessage类型的区别.篇幅有限这里不再多赘述

### 有图有真相

关于上次的源码分析,在此列出一张图表示,便于读者进行源码追踪

![https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/spark/spark_source.png](https://cdn.jsdelivr.net/gh/lemcoden/blog_picture/spark/spark_source.png)

spark源码1

## 进入正题

上篇,我们以Master为开端,整体把握了整个RPC环境是如何搭建和运行通信的,这次我们在理解了RPC环境的基础之上,看一下Master和Worker之间的角色启动流程,以及我们提交一个任务时,Driver端是如何将我们所指定的任务jar运行起来的

### worker开始

上次我们从Master源码开始,这次我们从worker的源码开始,上次我们已经给出worker的包名即org.apache.spark.deploy.worker.Worker,老规矩,也是看main方法

```scala
  def main(argStrings: Array[String]) {
    Thread.setDefaultUncaughtExceptionHandler(new SparkUncaughtExceptionHandler(
      exitOnUncaughtException = false))
    Utils.initDaemon(log)
    val conf = new SparkConf
    val args = new WorkerArguments(argStrings, conf)
    val rpcEnv = startRpcEnvAndEndpoint(args.host, args.port, args.webUiPort, args.cores,
      args.memory, args.masters, args.workDir, conf = conf)		
    val externalShuffleServiceEnabled = conf.getBoolean("spark.shuffle.service.enabled", false)
    val sparkWorkerInstances = scala.sys.env.getOrElse("SPARK_WORKER_INSTANCES", "1").toInt
    require(externalShuffleServiceEnabled == false || sparkWorkerInstances <= 1,
      "Starting multiple workers on one host is failed because we may launch no more than one " +
        "external shuffle service on each host, please set spark.shuffle.service.enabled to " +
        "false or set SPARK_WORKER_INSTANCES to 1 to resolve the conflict.")
    rpcEnv.awaitTermination()
  }
```

不能说是一模一样,可以说是完全一致,这里补充一句,最后的rpcEnv的<font color= #FFA500>awaitTermination</font>方法,调用<font color= #FFA500>dispatcher</font>的同名方法,<font color= #FFA500>dispatcher</font>又是调用<font color= #FFA500>threadpool</font>的同名方法,也就是说,RPCEnv环境启动,实质上是线程池的loop线程启动,可以让dispactcher不断轮询抽取发送到的数据

然后同理,我们进入到worker的<font color= #FFA500>startRpcEnvAndEndpoint</font>的方法里

```scala
 def startRpcEnvAndEndpoint(
      host: String,
      port: Int,
      webUiPort: Int,
      cores: Int,
      memory: Int,
      masterUrls: Array[String],
      workDir: String,
      workerNumber: Option[Int] = None,
      conf: SparkConf = new SparkConf): RpcEnv = {

    // The LocalSparkCluster runs multiple local sparkWorkerX RPC Environments
    val systemName = SYSTEM_NAME + workerNumber.map(_.toString).getOrElse("")
    val securityMgr = new SecurityManager(conf)
    val rpcEnv = RpcEnv.create(systemName, host, port, conf, securityMgr)
    val masterAddresses = masterUrls.map(RpcAddress.fromSparkURL(_))
    rpcEnv.setupEndpoint(ENDPOINT_NAME, new Worker(rpcEnv, webUiPort, cores, memory,
      masterAddresses, ENDPOINT_NAME, workDir, conf, securityMgr))
    rpcEnv
  }
```

rpcEnv的创建方法和Endpoint的注册方法这里不在多赘述,安全相关的跳过去,不具体研究,我们看一下<font color= #FFA500>masterUrls.map</font>方法,这个是master地址的映射方法,因为worker和master不一样,worker启动之后,需要拿到master的地址,和master进行主动通信,所以才有这么一个映射方法,而这里如果是动态,灵活的RPC架构这里应该设计为像dubbo一样具有注册发现的功能,但是和上篇博客类似,我们角色就那么几个,如果额外开发注册发现功能显的杀鸡焉用牛刀的意思

### worker注册通信流程

既然Epc通信环境理解的差不多了,那么我们就可以进入到下一个环节,即RPC环境下具体的通信流程,这里是以woker的注册流程为例

上篇博客说到,EndPoint一旦创建就会发送一个信息执行自己的onStart方法,那么我们首先看一下woker的onStart方法中都有些什么

```scala
override def onStart() {
    assert(!registered)
→    createWorkDir()
→    startExternalShuffleService()
    webUi = new WorkerWebUI(this, workDir, webUiPort)
    webUi.bind()

    workerWebUiUrl = s"http://$publicAddress:${webUi.boundPort}"
→    registerWithMaster()

    metricsSystem.registerSource(workerSource)
    metricsSystem.start()
    // Attach the worker metrics servlet handler to the web ui after the metrics system is started.
    metricsSystem.getServletHandlers.foreach(webUi.attachHandler)
  }
```

创建一个本地文件夹(类似于命名空间,工作空间这样的操作),开启shuffle服务,还有向Master注册自己

这其中的重点不言而喻,必然是注册Master,我们进入到<font color= #FFA500>registerWithMaster</font>方法

```scala
private def registerWithMaster() {
    // onDisconnected may be triggered multiple times, so don't attempt registration
    // if there are outstanding registration attempts scheduled.
    registrationRetryTimer match {
      case None =>
        registered = false
→        registerMasterFutures = tryRegisterAllMasters()
        connectionAttemptCount = 0
→        registrationRetryTimer = Some(forwordMessageScheduler.scheduleAtFixedRate(
          new Runnable {
            override def run(): Unit = Utils.tryLogNonFatalError {
              Option(self).foreach(_.send(ReregisterWithMaster))
            }
          },
          INITIAL_REGISTRATION_RETRY_INTERVAL_SECONDS,
          INITIAL_REGISTRATION_RETRY_INTERVAL_SECONDS,
          TimeUnit.SECONDS))
      case Some(_) =>
        logInfo("Not spawning another attempt to register with the master, since there is an" +
          " attempt scheduled already.")
    }
  }
```

<font color= #FFA500>tryRegisterAllMasters</font>?为什么是复数?当然是因为兼容HA的多Master的情况,下面是一个定时调度器,INITIAL_REGISTRATION_RETRY_INTERVAL_SECONDS的常量值为10,也就是说,如果没有回应的话,会每隔10秒向master发送信息.

然后再进入到tryRegisterAllMasters方法中

```scala
private def tryRegisterAllMasters(): Array[JFuture[_]] = {
→     masterRpcAddresses.map { masterAddress =>
→       registerMasterThreadPool.submit(new Runnable {
        override def run(): Unit = {
          try {
            logInfo("Connecting to master " + masterAddress + "...")
→             val masterEndpoint = rpcEnv.setupEndpointRef(masterAddress, Master.ENDPOINT_NAME)
→             sendRegisterMessageToMaster(masterEndpoint)
          } catch {
            case ie: InterruptedException => // Cancelled
            case NonFatal(e) => logWarning(s"Failed to connect to master $masterAddress", e)
          }
        }
      })
    }
  }
```

遍历所有master的地址,并通过线程池执行任务,任务内容是根据master的地址创建相应的EndPointRef并通过EndPointRef向Master本体发送信息(如果这里不懂请参照上篇博客)

然后我们再进入到<font color= #FFA500>sendRegisterMessageToMaster</font>方法

```scala
private def sendRegisterMessageToMaster(masterEndpoint: RpcEndpointRef): Unit = {
    masterEndpoint.send(RegisterWorker(
      workerId,
      host,
      port,
      self,
      cores,
      memory,
      workerWebUiUrl,
      masterEndpoint.address))
  }
```

发送了一个<font color= #FFA500>RegisterWoker</font>格式的数据,因为之前说过,EndPointRef的send方法对应Endpoint的receive方法,我们直接看Master的receive方法

```scala
override def receive: PartialFunction[Any, Unit] = {
....
    case RegisterWorker(
      id, workerHost, workerPort, workerRef, cores, memory, workerWebUiUrl, masterAddress) =>
      logInfo("Registering worker %s:%d with %d cores, %s RAM".format(
        workerHost, workerPort, cores, Utils.megabytesToString(memory)))
→        if (state == RecoveryState.STANDBY) {
        workerRef.send(MasterInStandby)
→        } else if (idToWorker.contains(id)) {
        workerRef.send(RegisterWorkerFailed("Duplicate worker ID"))
→        } else {
        val worker = new WorkerInfo(id, workerHost, workerPort, cores, memory,
          workerRef, workerWebUiUrl)
        if (registerWorker(worker)) {
          persistenceEngine.addWorker(worker)
          workerRef.send(RegisteredWorker(self, masterWebUiUrl, masterAddress))
          schedule()
→          } else {
          val workerAddress = worker.endpoint.address
          logWarning("Worker registration failed. Attempted to re-register worker at same " +
            "address: " + workerAddress)
          workerRef.send(RegisterWorkerFailed("Attempted to re-register worker at same address: "
            + workerAddress))
        }
      }
....
 }
```

receive方法是一个偏函数,即会根据输入参数的格式类型,匹配相应的代码块,这里只摘出RegisterWorker的代码块,注册分三种情况

1. 本地Master是Standby模式,通过wokerRef发送<font color= #FFA500>MasterInStandby</font>格式消息
2. worker已经在本地注册过,注册失败,发送<font color= #FFA500>RegisterWorkerFailed</font>格式消息
3. 注册成功,本地持久化引擎添加worker的信息(地址端口核数内存....),并发送<font color= #FFA500>RegisteredWorker</font>格式消息

我们再看以下对应worker的receive方法

```scala
override def receive: PartialFunction[Any, Unit] = synchronized {
....
    case msg: RegisterWorkerResponse =>
      handleRegisterResponse(msg)
....
}

case class RegisteredWorker(
      master: RpcEndpointRef,
      masterWebUiUrl: String,
      masterAddress: RpcAddress) extends DeployMessage with RegisterWorkerResponse
```

我们发现没有RegisteredWorker格式的分支,进入到RegisteredWorker,发现其继承自RegisterWorkerResponse,所以我们直接看RegisterWorkerResponse的分支信息,进入<font color= #FFA500>handleRegisterResponse</font>方法

```scala
private def handleRegisterResponse(msg: RegisterWorkerResponse): Unit = synchronized {
    msg match {
→      case RegisteredWorker(masterRef, masterWebUiUrl, masterAddress) =>
        registered = true
→       changeMaster(masterRef, masterWebUiUrl, masterAddress)
→       forwordMessageScheduler.scheduleAtFixedRate(new Runnable {
          override def run(): Unit = Utils.tryLogNonFatalError {
            self.send(SendHeartbeat)
          }
        }, 0, HEARTBEAT_MILLIS, TimeUnit.MILLISECONDS)
...
        masterRef.send(WorkerLatestState(workerId, execs.toList, drivers.keys.toSeq))
...
      case RegisterWorkerFailed(message) =>
        if (!registered) {
          logError("Worker registration failed: " + message)
          System.exit(1)
        }

      case MasterInStandby =>
        // Ignore. Master not yet ready.
    }
}

private val HEARTBEAT_MILLIS = conf.getLong("spark.worker.timeout", 60) * 1000 / 4
```

失败和Standby的逻辑不再多说,很简单,如果成功了,将会调用changeMaster方法,并且利用调度其定时发送心跳,心跳的默认为15秒

这里有个changeMaster方法,我们再往下看看

```scala
private def changeMaster(masterRef: RpcEndpointRef, uiUrl: String, masterAddress: RpcAddress) {
    // activeMasterUrl it's a valid Spark url since we receive it from master.
    activeMasterUrl = masterRef.address.toSparkURL
    activeMasterWebUiUrl = uiUrl
    masterAddressToConnect = Some(masterAddress)
    master = Some(masterRef)
    connected = true
    if (reverseProxy) {
      logInfo(s"WorkerWebUI is available at $activeMasterWebUiUrl/proxy/$workerId")
    }
    // Cancel any outstanding re-registration attempts because we found a new master
→     cancelLastRegistrationRetry()
  }
```

有个<font color= #FFA500>cancelLastRegistrationRetry</font>,继续往里走

```scala
private def cancelLastRegistrationRetry(): Unit = {
    if (registerMasterFutures != null) {
      registerMasterFutures.foreach(_.cancel(true))
      registerMasterFutures = null
    }
→     registrationRetryTimer.foreach(_.cancel(true))
    registrationRetryTimer = None
  }
```

我们之前不是说有个多次重试发送注册信息嘛,注册成功后这里会取消掉所有的定时发送

好了,这就是woker注册的整个通信流程,一旦这个走通spark内大部分的通信流程基本都可以搞的懂

### 提交任务流程

前面我们整个的RPC环境再加上Master与Worker角色,这算是对spark资源层最简单的理解,后期还会有更加深入的讲解,但是源码阅读都是循序渐进的,先把外层源码的壳子理解透彻,我们再深入,所以我们先从简单的资源层理解向简单的计算层理解过渡

说到计算,开始肯定离不开任务的提交,因此我们从spark-submit的shell脚本开始,

```bash
if [ -z "${SPARK_HOME}" ]; then
  source "$(dirname "$0")"/find-spark-home
fi

# disable randomized hash for string in Python 3.3+
export PYTHONHASHSEED=0

exec "${SPARK_HOME}"/bin/spark-class org.apache.spark.deploy.SparkSubmit "$@"
```

发现,很简单直接执行的 SparkSubmit类,我们进入SparkSubmit,看一下main函数

```scala
override def main(args: Array[String]): Unit = {
    // Initialize logging if it hasn't been done yet. Keep track of whether logging needs to
    // be reset before the application starts.
    val uninitLog = initializeLogIfNecessary(true, silent = true)

    val appArgs = new SparkSubmitArguments(args)
    if (appArgs.verbose) {
      // scalastyle:off println
      printStream.println(appArgs)
      // scalastyle:on println
    }
    appArgs.action match {
      case SparkSubmitAction.SUBMIT => submit(appArgs, uninitLog)
      case SparkSubmitAction.KILL => kill(appArgs)
      case SparkSubmitAction.REQUEST_STATUS => requestStatus(appArgs)
    }
  }
```

参数拼接转换就不多说了,重点看三个action,看来spark-submit不止能提交,还可以杀死容器,查看状态,笔者回头试了以下,发现help里面就有相关的功能的示例

```bash
Usage: spark-submit [options] <app jar | python file | R file> [app arguments]
Usage: spark-submit --kill [submission ID] --master [spark://...]
Usage: spark-submit --status [submission ID] --master [spark://...]
```

有时候,没有源码提醒一下,还真不知道有这东西

好了,收回来,我们重点看的是任务是如何提交的,所以需要进入submit方法

```scala
private def submit(args: SparkSubmitArguments, uninitLog: Boolean): Unit = {

    def doRunMain(): Unit = {...}

    // In standalone cluster mode, there are two submission gateways:
    //   (1) The traditional RPC gateway using o.a.s.deploy.Client as a wrapper
    //   (2) The new REST-based gateway introduced in Spark 1.3
    // The latter is the default behavior as of Spark 1.3, but Spark submit will fail over
    // to use the legacy gateway if the master endpoint turns out to be not a REST server.
→     if (args.isStandaloneCluster && args.useRest) {
      try {
        // scalastyle:off println
        printStream.println("Running Spark using the REST application submission protocol.")
        // scalastyle:on println
        doRunMain()
      } catch {
				......
      }
    // In all other modes, just run the main class as prepared
    } else {
→       doRunMain()
    }
  }
```

有一个嵌套函数doRunMain先跳过,先看下面的判断,发现会判断参数中是否有<font color= #FFA500>useRest</font>,rest风格的提交?感觉和livy有些关系,不过可以肯定的是我们提交都是直接使用的shell脚本,所以走的else分支,所以我们再展开<font color= #FFA500>doRunMain</font>方法

```bash
def doRunMain(): Unit = {
      if (args.proxyUser != null) {
        val proxyUser = UserGroupInformation.createProxyUser(args.proxyUser,
          UserGroupInformation.getCurrentUser())
        try {
          proxyUser.doAs(new PrivilegedExceptionAction[Unit]() {
            override def run(): Unit = {
→               runMain(args, uninitLog)
            }
          })
        } catch {
				   .....
        }
      } else {
        runMain(args, uninitLog)
      }
}
```

有个是否代理用户的判断,不过这不重要,再进入<font color= #FFA500>runMain</font>方法,也就是真正执行我们提交的主类的方法

```scala
private def runMain(args: SparkSubmitArguments, uninitLog: Boolean): Unit = {
    val (childArgs, childClasspath, sparkConf, childMainClass) = prepareSubmitEnvironment(args)
		.......
}
```

我们先看第一行代码,调用提交环境准备的方法,返回Tuple4格式的一些参数,

### 不同模式,不同运行方式

我们进入到<font color= #FFA500>prepareSubmitEnvironment</font>看一下参数如何生成的

```scala
private[deploy] def prepareSubmitEnvironment(
      args: SparkSubmitArguments,
      conf: Option[HadoopConfiguration] = None)
      : (Seq[String], Seq[String], SparkConf, String) = {
    try {
      doPrepareSubmitEnvironment(args, conf)
    } catch {
      case e: SparkException =>
        printErrorAndExit(e.getMessage)
        throw e
    }
  }
```

prepareSubmitEnvironment调用 <font color= #FFA500>doPrepareSubmitEnvironment</font>,所以再进入

```scala
private def doPrepareSubmitEnvironment(
      args: SparkSubmitArguments,
      conf: Option[HadoopConfiguration] = None)
      : (Seq[String], Seq[String], SparkConf, String) = {
    // Return values
    val childArgs = new ArrayBuffer[String]()
    val childClasspath = new ArrayBuffer[String]()
    val sparkConf = new SparkConf()
→     var childMainClass = ""

    // Set the cluster manager
→     val clusterManager: Int = args.master match {
      case "yarn" => YARN
      case "yarn-client" | "yarn-cluster" =>
        printWarning(s"Master ${args.master} is deprecated since 2.0." +
          " Please use master \"yarn\" with specified deploy mode instead.")
        YARN
      case m if m.startsWith("spark") => STANDALONE
      case m if m.startsWith("mesos") => MESOS
      case m if m.startsWith("k8s") => KUBERNETES
      case m if m.startsWith("local") => LOCAL
      case _ =>
        printErrorAndExit("Master must either be yarn or start with spark, mesos, k8s, or local")
        -1
    }
		.......
		if (args.isStandaloneCluster) {
→ 			childMainClass = STANDALONE_CLUSTER_SUBMIT_CLASS
		}
		.......
		if (deployMode == CLIENT) {
→       childMainClass = args.mainClass
		}
		........
}
→  private[deploy] val STANDALONE_CLUSTER_SUBMIT_CLASS = classOf[ClientApp].getName()
```

首先预告一下,这个方法巨........长,因为有很多集群部署模式的判断,前四行就是四个参数的初始化,我们重点关注mainClass,因为我们现在主要解决的问题就是我们的主类最终运行的是谁?

然后看下面会根据我们提交shell脚本时,master的参数的不同(资源管理组件的不同),赋值不同的集群管理值,我们目前只关注standlone下的Cluster模式和Client模式,其他的资源管理读者有兴趣可以自行研究

然后再往下,如果时standlone的cluster模式,会给我们的<font color= #FFA500>childMainClass</font>赋值<font color= #FFA500>ClientApp</font>的类,如果是client模式就会直接赋值我们提交jar包时- - class中的主类

好了,运行的主类知道了,我们再返回到runMain方法中

```scala
private def runMain(args: SparkSubmitArguments, uninitLog: Boolean): Unit = {
    val (childArgs, childClasspath, sparkConf, childMainClass) = prepareSubmitEnvironment(args)
		.......
→		val app: SparkApplication = if (classOf[SparkApplication].isAssignableFrom(mainClass)) {
      mainClass.newInstance().asInstanceOf[SparkApplication]
    } else {
      // SPARK-4170
      if (classOf[scala.App].isAssignableFrom(mainClass)) {
        printWarning("Subclasses of scala.App may not work correctly. Use a main() method instead.")
      }
      new JavaMainApplication(mainClass)
		}
...
→		app.start(childArgs.toArray, sparkConf)
...
}
private[spark] class ClientApp extends SparkApplication {
}
```

中间长段落跳过,我们直接看最后,有个app.start方法,把应用启动起来,把哪个应用启动起来?再往前,发现有个判断,判断我们要启动的class是不是SparkApplication的子类是返回本体,不是返回JavaMainApplication,查询了一下发现cluster模式下返回的ClientApp类就是SparkApplication子类,所以这段话可以这么理解

* cluster模式下 调用ClientApp的start方法

* client模式下 调用JavaMainApplication的start方法

那我们分别看一下其对应的start方法,先看JavaMainApplication的

```scala
override def start(args: Array[String], conf: SparkConf): Unit = {
→    val mainMethod = klass.getMethod("main", new Array[String](0).getClass)
    if (!Modifier.isStatic(mainMethod.getModifiers)) {
      throw new IllegalStateException("The main method in the given main class must be static")
    }

    val sysProps = conf.getAll.toMap
    sysProps.foreach { case (k, v) =>
      sys.props(k) = v
    }

→    mainMethod.invoke(null, args)
  }
```

直接拿到我们提交的类,通过反射运行了,也就是我们常常说的client模式程序运行在本地

再看一下,cluster模式下

```scala
override def start(args: Array[String], conf: SparkConf): Unit = {
→    val driverArgs = new ClientArguments(args)

    if (!conf.contains("spark.rpc.askTimeout")) {
      conf.set("spark.rpc.askTimeout", "10s")
    }
    Logger.getRootLogger.setLevel(driverArgs.logLevel)

    val rpcEnv =
      RpcEnv.create("driverClient", Utils.localHostName(), 0, conf, new SecurityManager(conf))

    val masterEndpoints = driverArgs.masters.map(RpcAddress.fromSparkURL).
      map(rpcEnv.setupEndpointRef(_, Master.ENDPOINT_NAME))
→    rpcEnv.setupEndpoint("client", new ClientEndpoint(rpcEnv, driverArgs, masterEndpoints, conf))

    rpcEnv.awaitTermination()
  }
```

将我们提交的包含主类在内的参数转换为ClientArguments格式,并在本地启动一个RPC环境,然后注册一个ClientEndPoint,并将转换后的参数输入到Endpoint

### 通信Master启动Driver

我们知道一旦Endpoint注册就一定会执行它的OnStart方法,我们进入<font color= #FFA500>ClientEndpoint</font>的OnStart方法看一下

```scala
override def onStart(): Unit = {
    driverArgs.cmd match {
      case "launch" =>
        // TODO: We could add an env variable here and intercept it in `sc.addJar` that would
        //       truncate filesystem paths similar to what YARN does. For now, we just require
        //       people call `addJar` assuming the jar is in the same directory.
→        val mainClass = "org.apache.spark.deploy.worker.DriverWrapper"
				.....
→        val command = new Command(mainClass,
          Seq("{{WORKER_URL}}", "{{USER_JAR}}", driverArgs.mainClass) ++ driverArgs.driverOptions,
          sys.env, classPathEntries, libraryPathEntries, javaOpts)
				......
→        val driverDescription = new DriverDescription(
          driverArgs.jarUrl,
          driverArgs.memory,
          driverArgs.cores,
          driverArgs.supervise,
          command)
→        asyncSendToMasterAndForwardReply[SubmitDriverResponse](
          RequestSubmitDriver(driverDescription))

      case "kill" =>
        val driverId = driverArgs.driverId
        asyncSendToMasterAndForwardReply[KillDriverResponse](RequestKillDriver(driverId))
    }
  }
```

首先判断我们是要运行提交还是要杀死进程,肯定运行提交啊,所以进入launch分支,首先赋值mainClass以<font color= #FFA500>"org.apache.spark.deploy.worker.DriverWrapper"</font>(这个需要记一下,后面会用到),然后将<font color= #FFA500>DriverWrapper</font>类和我们的提交的args.mainClass一起封装进command对象中,然后command和一些其他参数封装进driverDescription对象中,最终通过<font color= #FFA500>asyncSendToMasterAndForwardReply</font>发送给Master,不过这里有一个坑,我们看这个方法名好像是调用send方法发送的,但是进入内部

```scala
private def asyncSendToMasterAndForwardReply[T: ClassTag](message: Any): Unit = {
    for (masterEndpoint <- masterEndpoints) {
→      masterEndpoint.ask[T](message).onComplete {
        case Success(v) => self.send(v)
        case Failure(e) =>
          logWarning(s"Error sending messages to master $masterEndpoint", e)
      }(forwardMessageExecutionContext)
    }
  }
```

结果是调用的ask方法,所以我们接下来不是找的receive方法,而是,Master的<font color= #FFA500>receiveAndReply</font>方法

```scala
override def receiveAndReply(context: RpcCallContext): PartialFunction[Any, Unit] = {
    case RequestSubmitDriver(description) =>
      if (state != RecoveryState.ALIVE) {
        val msg = s"${Utils.BACKUP_STANDALONE_MASTER_PREFIX}: $state. " +
          "Can only accept driver submissions in ALIVE state."
        context.reply(SubmitDriverResponse(self, false, None, msg))
      } else {
        logInfo("Driver submitted " + description.command.mainClass)
        val driver = createDriver(description)
        persistenceEngine.addDriver(driver)
        waitingDrivers += driver
        drivers.add(driver)
→        schedule()

        // TODO: It might be good to instead have the submission client poll the master to determine
        //       the current status of the driver. For now it's simply "fire and forget".

        context.reply(SubmitDriverResponse(self, true, Some(driver.id),
          s"Driver successfully submitted as ${driver.id}"))
      }
}
```

然后就和worker注册差不多,根据创建的描述信息创建个Driver,并且添加到持久化引擎当中,并且把driver添加到<font color= #FFA500>waitingDrivers</font>,不过driver不是一个独立的程序,它是运行在Execuotor当中的,所以我们需要知道它什么时候放到Executor中.被Executor启动

那我们继续看schedule方法有什么

```scala
private def schedule(): Unit = {
    if (state != RecoveryState.ALIVE) {
      return
    }
    // Drivers take strict precedence over executors
→    val shuffledAliveWorkers = Random.shuffle(workers.toSeq.filter(_.state == WorkerState.ALIVE))
    val numWorkersAlive = shuffledAliveWorkers.size
    var curPos = 0
→    for (driver <- waitingDrivers.toList) { // iterate over a copy of waitingDrivers
      // We assign workers to each waiting driver in a round-robin fashion. For each driver, we
      // start from the last worker that was assigned a driver, and continue onwards until we have
      // explored all alive workers.
      var launched = false
      var numWorkersVisited = 0
      while (numWorkersVisited < numWorkersAlive && !launched) {
        val worker = shuffledAliveWorkers(curPos)
        numWorkersVisited += 1
        if (worker.memoryFree >= driver.desc.mem && worker.coresFree >= driver.desc.cores) {
          launchDriver(worker, driver)
          waitingDrivers -= driver
          launched = true
        }
        curPos = (curPos + 1) % numWorkersAlive
      }
    }
→    startExecutorsOnWorkers()
  }
```

其实<font color= #FFA500>Master.schedule()<</font>方法在注册worker时也执行了,不过上篇并没有重点提到,也就是说schedule会被多处调用,它主要有两个功能

1. 随机打乱workers,并且拿出一个worker,在其符合标准的(内存和和CPU核心数大于我们要求的driver的内存和核心数)executor中启动我们刚刚添加到watingDrivers列表的driver
2. 第三个箭头处,启动在Worker当中的Executor

我们目前只研究driver的启动所以进入到<font color= #FFA500>lanuchDriver</font>方法

```scala
private def launchDriver(worker: WorkerInfo, driver: DriverInfo) {
    logInfo("Launching driver " + driver.id + " on worker " + worker.id)
    worker.addDriver(driver)
    driver.worker = Some(worker)
→     worker.endpoint.send(LaunchDriver(driver.id, driver.desc))
    driver.state = DriverState.RUNNING
  }
```

打乱worker后随机挑选一个worker,然后发送<font color= #FFA500>LaunchDriver</font>格式的消息,消息内包含driver的id和描述信息,我们再看worker的接收方法

```scala
case LaunchDriver(driverId, driverDesc) =>
      logInfo(s"Asked to launch driver $driverId")
      val driver = new DriverRunner(
        conf,
        driverId,
        workDir,
        sparkHome,
        driverDesc.copy(command = Worker.maybeUpdateSSLSettings(driverDesc.command, conf)),
        self,
        workerUri,
        securityMgr)
→       drivers(driverId) = driver
→       driver.start()

→       coresUsed += driverDesc.cores
→       memoryUsed += driverDesc.mem
```

将driver相关信息塞进DriverRunner并运行,然后将driver使用的计算资源在可用资源中划去

### 题外分析jdk进程的创建

> 以下纯属笔者个人兴趣,与spark源码分析无关,只看spark源码的可以跳过本小节

笔者有一定的linux知识基础,也知道java是调用<font color= #FFA500>fork,clone,vfork</font>等系统函数启动的进程和线程,而这里Driver作为一个角色,绝对会以进程的方式被创建,所以这里笔者想确认一下,Driver在jdk当中是否确实是调用内核函数实现的

首先声明,本人使用的是linux系统版本的jdk,与windows版本大相径庭.

那我们继续跟踪<font color= #FFA500>DriverRunner</font>的start方法

```scala
/** Starts a thread to run and manage the driver. */
  private[worker] def start() = {
→    new Thread("DriverRunner for " + driverId) {
      override def run() {
        var shutdownHook: AnyRef = null
        try {
→          shutdownHook = ShutdownHookManager.addShutdownHook { () =>
            logInfo(s"Worker shutting down, killing driver $driverId")
            kill()
          }

          // prepare driver jars and run driver
→          val exitCode = prepareAndRunDriver()

          // set final state depending on if forcibly killed and process exit code
          finalState = if (exitCode == 0) {
            Some(DriverState.FINISHED)
          } else if (killed) {
            Some(DriverState.KILLED)
          } else {
            Some(DriverState.FAILED)
          }
        } catch {
		      ....
        }

        // notify worker of final driver state, possible exception
        worker.send(DriverStateChanged(driverId, finalState.get, finalException))
      }
    }.start()
  }
```

另起了一个线程进行driver进程的启动操作,

首先注册了一个钩子函数,在worker被杀死的时候同时杀死worker中的driver进程

然后运行prepareAndRunDriver启动driver进程并根据状态码更新driver运行状态.

那再进入<font color= #FFA500>prepareAndRunDriver</font>方法

```scala
private[worker] def prepareAndRunDriver(): Int = {
    val driverDir = createWorkingDirectory()
    val localJarFilename = downloadUserJar(driverDir)

    def substituteVariables(argument: String): String = argument match {
      case "{{WORKER_URL}}" => workerUrl
      case "{{USER_JAR}}" => localJarFilename
      case other => other
    }

    // TODO: If we add ability to submit multiple jars they should also be added here
→    val builder = CommandUtils.buildProcessBuilder(driverDesc.command, securityManager,
      driverDesc.mem, sparkHome.getAbsolutePath, substituteVariables)

→    runDriver(builder, driverDir, driverDesc.supervise)
  }
```

下在jar包,添加参数先略过,我们重点<font color= #FFA500> CommandUtils.buildProcessBuilder</font>方法,这个方法返回的进程构造器<font color= #FFA500>(ProcessBuilder)</font>已经不是spark的类,而是jdk的rt包的类

我们进入末尾的runDriver方法

```scala
private def runDriver(builder: ProcessBuilder, baseDir: File, supervise: Boolean): Int = {
    builder.directory(baseDir)
    def initialize(process: Process): Unit = {
      // Redirect stdout and stderr to files
      val stdout = new File(baseDir, "stdout")
      CommandUtils.redirectStream(process.getInputStream, stdout)

      val stderr = new File(baseDir, "stderr")
      val formattedCommand = builder.command.asScala.mkString("\"", "\" \"", "\"")
      val header = "Launch Command: %s\n%s\n\n".format(formattedCommand, "=" * 40)
      Files.append(header, stderr, StandardCharsets.UTF_8)
      CommandUtils.redirectStream(process.getErrorStream, stderr)
    }
    runCommandWithRetry(ProcessBuilderLike(builder), initialize, supervise)
  }
```

重定向标准输出,错误输出到文件,然后将budiler包装为ProcessBuilderLike类,输入到<font color= #FFA500>runCommandWithRetry</font>

```scala
private[worker] def runCommandWithRetry(
→      command: ProcessBuilderLike, initialize: Process => Unit, supervise: Boolean): Int = {
    var exitCode = -1
    // Time to wait between submission retries.
    var waitSeconds = 1
    // A run of this many seconds resets the exponential back-off.
    val successfulRunDuration = 5
    var keepTrying = !killed

    while (keepTrying) {
      logInfo("Launch Command: " + command.command.mkString("\"", "\" \"", "\""))

      synchronized {
        if (killed) { return exitCode }
→        process = Some(command.start())
        initialize(process.get)
      }

      val processStart = clock.getTimeMillis()
      exitCode = process.get.waitFor()

      // check if attempting another run
      keepTrying = supervise && exitCode != 0 && !killed
      if (keepTrying) {
        if (clock.getTimeMillis() - processStart > successfulRunDuration * 1000L) {
          waitSeconds = 1
        }
        logInfo(s"Command exited with status $exitCode, re-launching after $waitSeconds s.")
        sleeper.sleep(waitSeconds)
        waitSeconds = waitSeconds * 2 // exponential back-off
      }
    }

    exitCode
  }
```

代码虽然长,但大部分是log参数的拼接和状态码的转换我们重点看command(ProcessBuilderLike)的start方法

```scala
private[deploy] object ProcessBuilderLike {
  def apply(processBuilder: ProcessBuilder): ProcessBuilderLike = new ProcessBuilderLike {
→    override def start(): Process = processBuilder.start()
    override def command: Seq[String] = processBuilder.command().asScala
  }
}
```

调用jdk原生的<font color= #FFA500>processBuilder.start()</font>方法,那再进入原生的方法

```scala
// Only for use by ProcessBuilder.start()
    static Process start(String[] cmdarray,
                         java.util.Map<String,String> environment,
                         String dir,
                         ProcessBuilder.Redirect[] redirects,
                         boolean redirectErrorStream)
        throws IOException
    {
				.......

        FileInputStream  f0 = null;
        FileOutputStream f1 = null;
        FileOutputStream f2 = null;
        try {
            if (redirects == null) {
                std_fds = new int[] { -1, -1, -1 };
            } else {
                std_fds = new int[3];

                if (redirects[0] == Redirect.PIPE)
                    std_fds[0] = -1;
                else if (redirects[0] == Redirect.INHERIT)
                    std_fds[0] = 0;
                else {
                    f0 = new FileInputStream(redirects[0].file());
                    std_fds[0] = fdAccess.get(f0.getFD());
                }

                if (redirects[1] == Redirect.PIPE)
                    std_fds[1] = -1;
                else if (redirects[1] == Redirect.INHERIT)
                    std_fds[1] = 1;
                else {
                    f1 = new FileOutputStream(redirects[1].file(),
                                              redirects[1].append());
                    std_fds[1] = fdAccess.get(f1.getFD());
                }

                if (redirects[2] == Redirect.PIPE)
                    std_fds[2] = -1;
                else if (redirects[2] == Redirect.INHERIT)
                    std_fds[2] = 2;
                else {
                    f2 = new FileOutputStream(redirects[2].file(),
                                              redirects[2].append());
                    std_fds[2] = fdAccess.get(f2.getFD());
                }
            }
			  ........
→        return new UNIXProcess
            (toCString(cmdarray[0]),
             argBlock, args.length,
             envBlock, envc[0],
             toCString(dir),
                 std_fds,
             redirectErrorStream);
        } finally {
            // In theory, close() can throw IOException
            // (although it is rather unlikely to happen here)
            try { if (f0 != null) f0.close(); }
            finally {
                try { if (f1 != null) f1.close(); }
                finally { if (f2 != null) f2.close(); }
            }
        }
    }
```

又是以一长串代码,不过return之前的整长串代码可以用一句话描述,设置标准输入,标准输出和错误输出的文件描述符

而我们需要研究的重点在于最后返回的UNIX进程对象,再进入

```scala
UNIXProcess(final byte[] prog,
                final byte[] argBlock, final int argc,
                final byte[] envBlock, final int envc,
                final byte[] dir,
                final int[] fds,
                final boolean redirectErrorStream)
            throws IOException {

→        pid = forkAndExec(launchMechanism.ordinal() + 1,
                          helperpath,
                          prog,
                          argBlock, argc,
                          envBlock, envc,
                          dir,
                          fds,
                          redirectErrorStream);

        try {
            doPrivileged((PrivilegedExceptionAction<Void>) () -> {
                initStreams(fds);
                return null;
            });
        } catch (PrivilegedActionException ex) {
            throw (IOException) ex.getException();
        }
    }
```

执行了<font color= #FFA500>forkAndExec</font>方法返回进程ID,再进入

```scala
/**
     * Creates a process. Depending on the {@code mode} flag, this is done by
     * one of the following mechanisms:
     * <pre>
     *   1 - fork(2) and exec(2)
     *   2 - posix_spawn(3P)
     *   3 - vfork(2) and exec(2)
     *
     *  (4 - clone(2) and exec(2) - obsolete and currently disabled in native code)
     * </pre>
     * @param fds an array of three file descriptors.
     *        Indexes 0, 1, and 2 correspond to standard input,
     *        standard output and standard error, respectively.  On
     *        input, a value of -1 means to create a pipe to connect
     *        child and parent processes.  On output, a value which
     *        is not -1 is the parent pipe fd corresponding to the
     *        pipe which has been created.  An element of this array
     *        is -1 on input if and only if it is <em>not</em> -1 on
     *        output.
     * @return the pid of the subprocess
     */
→    private native int forkAndExec(int mode, byte[] helperpath,
                                   byte[] prog,
                                   byte[] argBlock, int argc,
                                   byte[] envBlock, int envc,
                                   byte[] dir,
                                   int[] fds,
                                   boolean redirectErrorStream)
        throws IOException;
```

最终!!!!!!!!!!!!!!到达了宇宙初始,通过forkAndExec的native方法调用linux的内核函数,注释已经写的非常清楚明了了,笔者的愿望达成了

### 从DriverWrapper到计算层(上半部)

之前源码分析到了Driver的进程已经起来了,具体运行的哪个类呢?当然是刚刚说明要着重记一下的<font color= #FFA500>org.apache.spark.deploy.worker.DriverWrapper</font>类了

然后我们进入DriverWrapper类看一下,DriverWrapper在运行main方法时都干了什么

```scala
def main(args: Array[String]) {
    args.toList match {
......
        // Delegate to supplied main class
        val clazz = Utils.classForName(mainClass)
→        val mainMethod = clazz.getMethod("main", classOf[Array[String]])
→        mainMethod.invoke(null, extraArgs.toArray[String])
.......
        rpcEnv.shutdown()

      case _ =>
        // scalastyle:off println
        System.err.println("Usage: DriverWrapper <workerUrl> <userJar> <driverMainClass> [options]")
        // scalastyle:on println
        System.exit(-1)
    }
  }
```

表示长代码看的笔者头大,就直接捡起重点的展示,Driver里面就直接运行了我们提交的jar包的主类

但是有个问题,我们的主类绝对不会只运行在当前的单进程当中,而是应该分布式的去运行,所以接下来从笔者将会从计算层开始分析,从源码去理解算子是如何散布到分布式的集群当中的

首先我们先拿出一个计算层的示例代码来

```scala

object lesson01_rdd_api01 {

  def main(args: Array[String]): Unit = {
		val conf: SparkConf = new SparkConf().setMaster("local").setAppName("test01")
    val sc = new SparkContext(conf)
    val dataRDD: RDD[Int] = sc.parallelize( List(1,2,3,4,5,4,3,2,1) )
		val res: RDD[Int] = dataRDD.map((_,1)).reduceByKey(_+_).map(_._1)
    res.foreach(println)
	}
}
```

发现之后所有的RDD的产生都来自于SparkContext,那么我们就首先分析一下SparkContext

### 注册一个Application

当我打开<font color= #FFA500>SparkContext</font>的时候,一大堆的变量扑面而来,好家伙2300多行代码,所以我们只捡主要的说一下

```scala
private var _env: SparkEnv = _
........
// Create and start the scheduler
    val (sched, ts) = SparkContext.createTaskScheduler(this, master, deployMode)
    _schedulerBackend = sched
    _taskScheduler = ts
    _dagScheduler = new DAGScheduler(this)
........
    // start TaskScheduler after taskScheduler sets DAGScheduler reference in DAGScheduler's
    // constructor
    _taskScheduler.start()
.......
```

首先要提点一下最最重点也是最最复杂的对象<font color= #FFA500>SparkEnv,sparkEnv</font>里面有<font color= #FFA500>ShuffleManager,MemoryManager,BlockManager</font>等等计算层不可获缺的管理类,不过笔者只是提前说一下,因为其复杂程度远超本篇博客所能解释的量,所以目前还是聊一下其他两个对象(还有一个<font color= #FFA500>DAGScheduler</font>留到下期)

1. taskScheduler
2. schedulerBackend

首先进入<font color= #FFA500>createTaskScheduler</font>方法,看一下这两个对象是如何建立起来的?进方法之前需要先记录一下,这里taskScheduler会调用start方法

```scala
private def createTaskScheduler(
      sc: SparkContext,
      master: String,
      deployMode: String): (SchedulerBackend, TaskScheduler) = {
    import SparkMasterRegex._

    // When running locally, don't try to re-execute tasks on failure.
    val MAX_LOCAL_TASK_FAILURES = 1

    master match {
		.....
					case SPARK_REGEX(sparkUrl) =>
			        val scheduler = new TaskSchedulerImpl(sc)
			        val masterUrls = sparkUrl.split(",").map("spark://" + _)
			        val backend = new StandaloneSchedulerBackend(scheduler, sc, masterUrls)
			        scheduler.initialize(backend)
			        (backend, scheduler)
		.....

		}
}
```

进入方法方法之后发现,create方法会根据master的输入格式返回不同的Scheduler对象,我们调用SparkContext.setMaster有各种格式,比如local,local[*],spark://等等,目前我们专注于Spark协议开头的格式,所以这里只显示出来了SPARK_REGEX分支.

它是直接new了一个<font color= #FFA500>TaskSchedulerImpl</font>实现类,,也就是说TaskScheduler本身是写成一个接口(或者叫Scala当中的trait),为了方便后期的扩展实现.

然后new了一个<font color= #FFA500>StandloneSchedulerBackend</font>,并且把TaskScheduler塞了进去

backend单词直译为后端,这个应该是TaskSechduler的守护线程,我们开看一下StandloneSchedulerBackend继承关系

```scala
private[spark] class StandaloneSchedulerBackend(
    scheduler: TaskSchedulerImpl,
    sc: SparkContext,
    masters: Array[String])
  extends CoarseGrainedSchedulerBackend(scheduler, sc.env.rpcEnv)
  with StandaloneAppClientListener
  with Logging {
```

它继承自一个CoarsedGrained前缀的SchedulerBackend,为什么单独把粗粒度这个单词放在这里呢?因为这个单词很眼熟啊,我们好像在哪里见过..................

对,就是在部署Standlone模式的Executor的时候,集群某个节点总有一个带粗粒度前缀的Executor,既然都有CoarsedGrained前缀,那么他们总会有一些不可告人的共通点,这个等一下解释,时机尚未成熟

那往回倒一倒,<font color= #FFA500>createTaskScheduler</font>除了创建了两个Scheduler之外,TaskScheduler还调用initialize方法,进入这个方法看一下

```scala
def initialize(backend: SchedulerBackend) {
    this.backend = backend
    schedulableBuilder = {
      schedulingMode match {
        case SchedulingMode.FIFO =>
          new FIFOSchedulableBuilder(rootPool)
        case SchedulingMode.FAIR =>
          new FairSchedulableBuilder(rootPool, conf)
        case _ =>
          throw new IllegalArgumentException(s"Unsupported $SCHEDULER_MODE_PROPERTY: " +
          s"$schedulingMode")
      }
    }
    schedulableBuilder.buildPools()
  }
```

第一句话,将<font color= #FFA500>SchedulerBackend</font>对象赋值给backend,之后,我只能说一句

哦~~~~设置调度模式,Spark Standlone的调度模式只有两种,公平调度和FIFO,这个就不多说了

然后我们再往回倒一倒,刚才说,<font color= #FFA500>taskScheduler</font>创建的时候,会调用它的start方法,那我们进入TaskSchedulerImpl的start方法看一下

```scala
override def start() {
    backend.start()

    if (!isLocal && conf.getBoolean("spark.speculation", false)) {
      logInfo("Starting speculative execution thread")
      speculationScheduler.scheduleWithFixedDelay(new Runnable {
        override def run(): Unit = Utils.tryOrStopSparkContext(sc) {
          checkSpeculatableTasks()
        }
      }, SPECULATION_INTERVAL_MS, SPECULATION_INTERVAL_MS, TimeUnit.MILLISECONDS)
    }
  }
```

首先调用了backend的start方法,那再进<font color= #FFA500>StandloneSchedulerBackend.start</font>方法当中

```scala
override def start() {
    super.start()
		....
  }
```

后面的东西很多,先看第一句,它先调用父类的start方法,那么我们进入粗粒度的父类看一下

```scala
override def start() {
    val properties = new ArrayBuffer[(String, String)]
    for ((key, value) <- scheduler.sc.conf.getAll) {
      if (key.startsWith("spark.")) {
        properties += ((key, value))
      }
    }

    // TODO (prashant) send conf instead of properties
    driverEndpoint = createDriverEndpointRef(properties){
				rpcEnv.setupEndpoint(ENDPOINT_NAME, createDriverEndpoint(properties){
					new DriverEndpoint(rpcEnv, properties)
				})
		}
  }
```

表示不想一层层往里面进了,就把嵌套的方法都展开了,前面的将参数添加到本地就不说了,重点是后面这句,在本地创建了一个DriverEndPoint并注册到RPCEnv环境当中,注意这个DriverEndPoint 是TaskSchduler的内部类,它才是真正的driver角色,也就是说前面的driverWrapper是个容器,通过运行<font color= #FFA500>mainClass → new sparkContext → new TaskScheduler → new BackendScheduler → start TaskScheduler → start BackendScheduler</font>最终注册了一个真正的Driver角色,那之后的onStart 方法分析,这里就不多说了,读者有兴趣可以自己深入了解.

我们继续往下分析,回到StandloneSchedulerBackend的start方法当中

```scala
override def start() {
    super.start()
		....
		val command = Command("org.apache.spark.executor.CoarseGrainedExecutorBackend",
      args, sc.executorEnvs, classPathEntries ++ testingClassPath, libraryPathEntries, javaOpts)
		....
		val appDesc = ApplicationDescription(sc.appName, maxCores, sc.executorMemory, command,
      webUrl, sc.eventLogDir, sc.eventLogCodec, coresPerExecutor, initialExecutorLimit)
    client = new StandaloneAppClient(sc.env.rpcEnv, masters, appDesc, this, conf)
    client.start()
  }
```

首先,我们看到了粗粒度的<font color= #FFA500>Execuor</font>类,将它封装成Command,然后塞进<font color= #FFA500>ApplicationDescription</font>里

接下来要干什么?........................................................对就是启动一个应用,我们只前看到有DriverDescription会启动一个Driver,那对应的这个就是启动一个Application了,那么我们进入<font color= #FFA500>StandaloneAppClient</font>的start方法中

```scala
def start() {
    // Just launch an rpcEndpoint; it will call back into the listener.
    endpoint.set(rpcEnv.setupEndpoint("AppClient", new ClientEndpoint(rpcEnv)))
  }
```

注册了一个<font color= #FFA500>ClientEndPoint</font>那再进ClientEndpoint的start方法

```scala
override def onStart(): Unit = {
      try {
        registerWithMaster(1)
      } catch {
        case e: Exception =>
          logWarning("Failed to connect to master", e)
          markDisconnected()
          stop()
      }
    }
```

好嘛,又是向Master注册,不过这里是注册一个Application,剩下的笔者就不重复展示了,直接说这个是发送一个<font color= #FFA500>RegisterApplication</font>格式的消息,那么我们从Master的receive方法里面去找

```scala
case RegisterApplication(description, driver) =>
      // TODO Prevent repeated registrations from some driver
      if (state == RecoveryState.STANDBY) {
        // ignore, don't send response
      } else {
        logInfo("Registering app " + description.name)
        val app = createApplication(description, driver)
        registerApplication(app)
        logInfo("Registered app " + description.name + " with ID " + app.id)
        persistenceEngine.addApplication(app)
        driver.send(RegisteredApplication(app.id, self))
        schedule()
      }
```

通过description和driver(EndpointRef)两个对象真正创建一个应用

注册Application到这里基本也就结尾了

不过我们发现这边最后也调用了schedule方法,刚刚调用schedule方法,是为driver寻找要执行的worker,schedule还有一个作用是启动workder中的executor,启动它给谁用呢? 

当然是Application了,所以下期博客会从给Apllication申请Executor资源开始讲起.

好的,本期结束,bye,bye!



