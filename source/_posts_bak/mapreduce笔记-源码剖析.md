---
title: mapreduce笔记-源码剖析
date: 2020-08-21 17:56:07
categories: hadoop生态
author: Lemcoden
tags:
    - hadoop生态
    - 分布式
cover_picture: http://picture.lemcoden.xyz/cover_picture/mapreduce.jpg
---
#### 为什么要看源码
1.为了更好的使用框架的Api解决问题,比如说我们遇到一个问题,需要修改mapreduce分片的大小,如果没看过源码,可能会写很多代码,甚至重新调整文件block的大小上传,但是看过源码的都懂,只要简单的修改minSplite和maxSplite这两个配置属性就可以.
2.为了学习框架本身的设计方法,应用到日常开发中.
(此次源码分析的hadoop版本为2.7.2)

<!--more-->

#### 怎么看源码
要有目的性的的看源码,如果不带目的直接看的话,会很晕,源码一般信息量很大,而且很多部分是没有必要的,我们要取其精髓,忽略与当前目标无关的部分.并将重要的部分记录下来,最好是自己可以用伪代码实现,并且能够讲出其中的逻辑点和技术应用点
#### mapreduce源码梗概
mapreduce笔者目前了解的主要有三部分,client端,map计算端的输入输出,reduce计算端的输入输出.
client端主要验证client端的任务,以及关键切片部分的逻辑
map端和reduce端输入输出,一是看数据格式相关的转换
二是看shuffle的主要流程,看有哪些可以在开发过程中可以微调的地方
#### client端
```
job.waitForCompletion(true);
```
我们编写mapreduce程序的时候到最后执行这个方法的时候,任务才会真正提交,
那我们提交任务之后客户端都是如何做得呢?
点进去查看源码
```
public boolean waitForCompletion(boolean verbose
                                   ) throws IOException, InterruptedException,
                                            ClassNotFoundException {
    if (state == JobState.DEFINE) {  //检查任务状态,是否允许提交
      submit(); //提交任务方法
    }
    if (verbose) {
      monitorAndPrintJob(); //监控并且获取任务的详细运行信息
    } else ...
    return isSuccessful();
  }
```
提交之后,再调用方法获取任务的详细信息,可见这个任务是异步任务.
我们关系心的任务如何提交的,那么就进入submit方法
```
public void submit()
       throws IOException, InterruptedException, ClassNotFoundException {
  ensureState(JobState.DEFINE);
  setUseNewAPI();  //hadoop1.x和hadoop2.x的mapreduce架构不同,所以这里是新版API
  connect(); //连接yarn resourceManager
  final JobSubmitter submitter =
      getJobSubmitter(cluster.getFileSystem(), cluster.getClient()); //获取集群HDFS操作对象和Client对象,为以后把分片信息,配置文件,jar包,通过FileSystem上传到hdfs上
  status = ugi.doAs(new PrivilegedExceptionAction<JobStatus>() {
    public JobStatus run() throws IOException, InterruptedException,
    ClassNotFoundException {
      return submitter.submitJobInternal(Job.this, cluster); //这里就是提交Job的地方
    }
  });
  state = JobState.RUNNING;
  LOG.info("The url to track the job: " + getTrackingURL());
 }
```
再进入submitJobInternal方法,然后发现注释这部分很有东西
```
Internal method for submitting jobs to the system.
The job submission process involves:
1.Checking the input and output specifications of the job.
2.Computing the InputSplits for the job.
3.Setup the requisite accounting information for the DistributedCache of the job, if necessary.
4.Copying the job's jar and configuration to the map-reduce system directory on the distributed file-system.
5.Submitting the job to the JobTracker and optionally monitoring it's status.
```
简单的翻译以下就懂了,里面会
1. 检查job输入输出路径
2. 计算分片的大小
3. 有必要的话,为作业的缓存设置账户信息
4. 把job的jar包,配置文件拷贝到hdfs
5. 提交job到JobTracker

然后我们再看代码,因为源代码比较多,这里只挑出重要的伪代码
```
JobStatus submitJobInternal(Job job, Cluster cluster)
  throws ClassNotFoundException, InterruptedException, IOException {
    //validate the jobs output specs
    checkSpecs(job);  //这个就是检查文件路径的方法

    ...

    int maps = writeSplits(job, submitJobDir);//写入切片信息,返回切片数量

    ...

    String queue = conf.get(MRJobConfig.QUEUE_NAME,
        JobConf.DEFAULT_QUEUE_NAME); // 获取任务队列名,源码中有很多这样的获取配置信息的代码,这里只挑出一个说明一下

    ...

    // Write job file to submit dir
     writeConf(conf, submitJobFile); //写入conf文件到hdfs上

    ...

     //真正提交客户端的方法
     status = submitClient.submitJob(
           jobId, submitJobDir.toString(), job.getCredentials());
  }
```
client的用户任务,在这里如何调用的基本了解清除了,我们重点看切片是如何写入的,毕竟这是hadoop生态的一个要点:如何通过分片实现计算向数据移动的,点开writeSplite方法
```
private int writeSplits(org.apache.hadoop.mapreduce.JobContext job,
    Path jobSubmitDir) throws IOException,
    InterruptedException, ClassNotFoundException {
  JobConf jConf = (JobConf)job.getConfiguration();
  int maps;
  if (jConf.getUseNewMapper()) {
    maps = writeNewSplits(job, jobSubmitDir); //hadoop2.x使用newApi,所以进入这个方法
  } else {
    maps = writeOldSplits(jConf, jobSubmitDir);
  }
  return maps;
}
```
```
private <T extends InputSplit>
 int writeNewSplits(JobContext job, Path jobSubmitDir) throws IOException,
     InterruptedException, ClassNotFoundException {
       List<InputSplit> splits = input.getSplits(job);//不解释,再进入getSpiltes方法
}
```
进入之后,发现是InputFormat是个接口,有多个子类,那怎么办?查看子类,有 DB数据库的,有Line管每行记录的,切片当然是以文件系统为依托,所以选FileInputFormat
点进去
```
public List<InputSplit> getSplits(JobContext job) throws IOException {
  long minSize = Math.max(getFormatMinSplitSize(), getMinSplitSize(job));
  long maxSize = getMaxSplitSize(job);
  ...
  long blockSize = file.getBlockSize();
  long splitSize = computeSplitSize(blockSize, minSize, maxSize);
  ...
  long bytesRemaining = length;
  while (((double) bytesRemaining)/splitSize > SPLIT_SLOP) {
            int blkIndex = getBlockIndex(blkLocations, length-bytesRemaining);
            splits.add(makeSplit(path, length-bytesRemaining, splitSize,
                        blkLocations[blkIndex].getHosts(),
                        blkLocations[blkIndex].getCachedHosts()));
            bytesRemaining -= splitSize;
    }

    return splites;
  }
```
最后终于找到了关于切片的代码,首先开头有两个值minSize和maxSize,分别进入这些方法,发现默认的是0,和long型的最大值,并且受SPLIT_MINSIZE(mapreduce.input.fileinputformat.split.minsize)和SPLIT_MAXSIZE(mapreduce.input.fileinputformat.split.maxsize)这两个配置变量控制,然后继续往下走,有个cpmputeSpliteSize方法,用到了minSize和maxSize还有BlockSize,进入之后我们总算知道了切片如何计算大小
```
Math.max(minSize, Math.min(maxSize, blockSize))
```
<font color="#00FF00">它的语义就是以minSize为最小边界,maxSize为最大边界
如果blockSize没有超过最大最小边界,则SpliteSize取BlockSize的值
如果超过边界则取边界值.</font><br/>
继续追getSplites的代码
有一个getBlockIndex方法,获取块索引,并且块索引最后会放到切片信息中,
我们进入这个方法发现
```
protected int getBlockIndex(BlockLocation[] blkLocations,
                              long offset) {
    for (int i = 0 ; i < blkLocations.length; i++) {
      // is the offset inside this block?
      if ((blkLocations[i].getOffset() <= offset) &&
          (offset < blkLocations[i].getOffset() + blkLocations[i].getLength())){
        return i;
      }
    }
  }
```
注意if判断方法,语义就是如何取得切片的block索引,就是对切片在文件中偏移量,做一次"向下取整",比如说第二block块的偏移量是50,而第二个切片的偏移量是75,位于第二个和第三个块(100)偏移量之间,也就是说,在真正进行计算的时候,会从块的第50的偏移量读取,<br/>
<font color="#00ff00">这就是为什么我们一般把分片大小设置为块大小的倍数,因为这样可以避免交叉读写.</font><br/>
最后就是写入分片信息包括分片的hosts,size,filepath,offset<br/>
有了这些信息,就可以支持日后的计算能够保证计算程序找到分片的位置,也就是支持计算向数据移动<br/>
#### map端源码
首先明确目的,我们Map端的源码是对输入输出进行分析,主要分析map两端的输入输出,
#### 输入
已知我们Map是通过MapTask类运行的,那么我们就先进入MapTask类,先找run方法
```
@Override
 public void run(final JobConf job, final TaskUmbilicalProtocol umbilical)
   throws IOException, ClassNotFoundException, InterruptedException {


     if (conf.getNumReduceTasks() == 0) {
       mapPhase = getProgress().addPhase("map", 1.0f);
     } else {
       // If there are reducers then the entire attempt's progress will be
       // split between the map phase (67%) and the sort phase (33%).
       mapPhase = getProgress().addPhase("map", 0.667f);
       sortPhase  = getProgress().addPhase("sort", 0.333f);
     }

   ...
   if (useNewApi) {
     runNewMapper(job, splitMetaInfo, umbilical, reporter);
   } else {
     runOldMapper(job, splitMetaInfo, umbilical, reporter);
   }
   done(umbilical, reporter);
 }
```
首先映入眼帘的是getNumReduceTasks(),获取Reduce的数量,如果数量为零则不进行排序计算,不为排序任务分配全中
然后到下面的runNewMapper点进去
```
@SuppressWarnings("unchecked")
  private <INKEY,INVALUE,OUTKEY,OUTVALUE>
  void runNewMapper(final JobConf job,
                    final TaskSplitIndex splitIndex,
                    final TaskUmbilicalProtocol umbilical,
                    TaskReporter reporter
                    ) throws IOException, ClassNotFoundException,
                             InterruptedException {
    // make a task context so we can get the classes
    org.apache.hadoop.mapreduce.TaskAttemptContext taskContext =
      new org.apache.hadoop.mapreduce.task.TaskAttemptContextImpl(job,
                                                                  getTaskID(),
                                                                  reporter);
    // make a mapper
    org.apache.hadoop.mapreduce.Mapper<INKEY,INVALUE,OUTKEY,OUTVALUE> mapper =
      (org.apache.hadoop.mapreduce.Mapper<INKEY,INVALUE,OUTKEY,OUTVALUE>)
        ReflectionUtils.newInstance(taskContext.getMapperClass(), job);
    // make the input format
    org.apache.hadoop.mapreduce.InputFormat<INKEY,INVALUE> inputFormat =
      (org.apache.hadoop.mapreduce.InputFormat<INKEY,INVALUE>)
        ReflectionUtils.newInstance(taskContext.getInputFormatClass(), job);//初始化InputFormat
    // rebuild the input split
    org.apache.hadoop.mapreduce.InputSplit split = null;
    split = getSplitDetails(new Path(splitIndex.getSplitLocation()),
        splitIndex.getStartOffset());//获取切片信息,保证自己拿到最近的切片数据.
    LOG.info("Processing split: " + split);

    org.apache.hadoop.mapreduce.RecordReader<INKEY,INVALUE> input =
      new NewTrackingRecordReader<INKEY,INVALUE>
        (split, inputFormat, reporter, taskContext);

    job.setBoolean(JobContext.SKIP_RECORDS, isSkipping());
    org.apache.hadoop.mapreduce.RecordWriter output = null;

    // get an output object
    if (job.getNumReduceTasks() == 0) {
      output =
        new NewDirectOutputCollector(taskContext, job, umbilical, reporter);
    } else {
      output = new NewOutputCollector(taskContext, job, umbilical, reporter);
    }

    org.apache.hadoop.mapreduce.MapContext<INKEY, INVALUE, OUTKEY, OUTVALUE>
    mapContext =
      new MapContextImpl<INKEY, INVALUE, OUTKEY, OUTVALUE>(job, getTaskID(),
          input, output,
          committer,
          reporter, split);

    org.apache.hadoop.mapreduce.Mapper<INKEY,INVALUE,OUTKEY,OUTVALUE>.Context
        mapperContext =
          new WrappedMapper<INKEY, INVALUE, OUTKEY, OUTVALUE>().getMapContext(
              mapContext);

    try {
      input.initialize(split, mapperContext);
      mapper.run(mapperContext);
      mapPhase.complete();
      setPhase(TaskStatus.Phase.SORT);
      statusUpdate(umbilical);
      input.close();
      input = null;
      output.close(mapperContext);
      output = null;
    } finally {
      closeQuietly(input);
      closeQuietly(output, mapperContext);
    }
  }
```
我们先看下面try cacth里面的东西,一般看源码,try语句块里面的东西是比较重要的,
在try语句块当中,我们看到了,mapper对象通过run方法运行我们开发编写的map方法,
并且且有自己的输入输出.
然后从头开始捋,首先通过反射将我们编写的Map对象赋值给Mapper,中间注释的跳过,直接开门见山,我们看一下Mapper的输入类,进入到NewTrackingRecordReader
```
NewTrackingRecordReader(org.apache.hadoop.mapreduce.InputSplit split,
       org.apache.hadoop.mapreduce.InputFormat<K, V> inputFormat,
       TaskReporter reporter,
       org.apache.hadoop.mapreduce.TaskAttemptContext taskContext)
       ...
       throws InterruptedException, IOException {
     this.real = inputFormat.createRecordReader(split, taskContext);
     ...
   }

```
进入后发现这是个包装类,有nextKeyalue方法获取我们Map中所需要的键值对,而他调用的是real对象的nextKeyValue,
而real对象就是我们的LineRecordReader类型.进入有一个初始化类initialize
```
public void initialize(InputSplit genericSplit,
                       TaskAttemptContext context) throws IOException {
  FileSplit split = (FileSplit) genericSplit;
  Configuration job = context.getConfiguration();
  this.maxLineLength = job.getInt(MAX_LINE_LENGTH, Integer.MAX_VALUE);
  start = split.getStart();
  end = start + split.getLength();
  final Path file = split.getPath();

  // open the file and seek to the start of the split
  final FileSystem fs = file.getFileSystem(job);
  fileIn = fs.open(file);
  ...
    fileIn.seek(start);
  ...
  if (start != 0) {
     start += in.readLine(new Text(), 0,maxBytesToConsume(start));
   }
   this.pos = start;
}
```
通过seek方法获从自己相应的切片偏移量开始读取信息,
最后一个判断是,默认跳过第一条数据的读取,因为切块的原因很有可能第一条信息不完整.然后我们知道,NewTrackingRecordReader在Context对象里而我们的LineRecordReader在NewTrackingRecordReader当中,所以其实最后context对象调用的nextKeyValue其实调用的是LineRecordReader的方法
```
public boolean nextKeyValue() throws IOException {
```
    key.set(pos);
    ```
  }

```
而在nextKeyValue里面有一个key.set(pos)其实就是文件的行号赋值给key
#### 输出
好了,输入看完了我们再看一下输出,重新回到MapTask类,我们点开输出类,NewOutputCollector
```
NewOutputCollector(org.apache.hadoop.mapreduce.JobContext jobContext,
                      JobConf job,
                      TaskUmbilicalProtocol umbilical,
                      TaskReporter reporter
                      ) throws IOException, ClassNotFoundException {
     collector = createSortingCollector(job, reporter);//获取排序的数据收集器
     partitions = jobContext.getNumReduceTasks();//根据reduce数量进行分区,如果分区数量等于1使用默认的分区器将数据分区为一
     if (partitions > 1) {
       partitioner = (org.apache.hadoop.mapreduce.Partitioner<K,V>)
         ReflectionUtils.newInstance(jobContext.getPartitionerClass(), job);
     } else {
       partitioner = new org.apache.hadoop.mapreduce.Partitioner<K,V>() {
         @Override
         public int getPartition(K key, V value, int numPartitions) {
           return partitions - 1;
         }
       };
     }
   }
```
代码的中文注释已经比较详细了,我们继续走,看看排序收集器里面都是什么东西<br/>
打开createSortingCollector
```
private <KEY, VALUE> MapOutputCollector<KEY, VALUE>
         createSortingCollector(JobConf job, TaskReporter reporter) {
     Class<?>[] collectorClasses = job.getClasses(
      JobContext.MAP_OUTPUT_COLLECTOR_CLASS_ATTR, MapOutputBuffer.class);
    int remainingCollectors = collectorClasses.length;
    Exception lastException = null;
    for (Class clazz : collectorClasses) {
      try {
        if (!MapOutputCollector.class.isAssignableFrom(clazz)) {
          throw new IOException("Invalid output collector class: " + clazz.getName() +
            " (does not implement MapOutputCollector)");
        }
        Class<? extends MapOutputCollector> subclazz =
          clazz.asSubclass(MapOutputCollector.class);
        LOG.debug("Trying map output collector class: " + subclazz.getName());
        MapOutputCollector<KEY, VALUE> collector =
          ReflectionUtils.newInstance(subclazz, job);
        collector.init(context);
        LOG.info("Map output collector class = " + collector.getClass().getName());
        return collector;
      }
   }
```
最后知道了,输出数据的排序收集器就是唤醒缓冲区MapOutputBuffer的子类,打开他的init方法
```
public void init(MapOutputCollector.Context context
                    ) throws IOException, ClassNotFoundException {


      ...
      //sanity checks
      final float spillper =
        job.getFloat(JobContext.MAP_SORT_SPILL_PERCENT, (float)0.8);
      final int sortmb = job.getInt(JobContext.IO_SORT_MB, 100);     
      ...
      sorter = ReflectionUtils.newInstance(job.getClass("map.sort.class",
            QuickSort.class, IndexedSorter.class), job);
    
      ...
      // k/v serialization
      comparator = job.getOutputKeyComparator();
      keyClass = (Class<K>)job.getMapOutputKeyClass();
      valClass = (Class<V>)job.getMapOutputValueClass();
      serializationFactory = new SerializationFactory(job);
      keySerializer = serializationFactory.getSerializer(keyClass);
      keySerializer.open(bb);
      valSerializer = serializationFactory.getSerializer(valClass);
      valSerializer.open(bb);
    
      ...
      // compression
      if (job.getCompressMapOutput()) {
        Class<? extends CompressionCodec> codecClass =
          job.getMapOutputCompressorClass(DefaultCodec.class);
        codec = ReflectionUtils.newInstance(codecClass, job);
      } else {
        codec = null;
      }
      ...
      if (combinerRunner != null) {
        final Counters.Counter combineOutputCounter =
          reporter.getCounter(TaskCounter.COMBINE_OUTPUT_RECORDS);
        combineCollector= new CombineOutputCollector<K,V>(combineOutputCounter, reporter, job);
      } else {
        combineCollector = null;
      }
      ...
      spillThread.setDaemon(true);
      spillThread.setName("SpillThread");
      spillLock.lock();
      try {
        spillThread.start();
        while (!spillThreadRunning) {
          spillDone.await();
        }
      } catch (InterruptedException e) {
        throw new IOException("Spill thread failed to initialize", e);
      } finally {
        spillLock.unlock();
      }
      if (sortSpillException != null) {
        throw new IOException("Spill thread failed to initialize",
            sortSpillException);
      }
    }

```
下面的粗略的的分组,代码分别是
* 设置缓冲取大小和溢写百分比(默认100M和0.8)
* 设置缓冲区数据的排序类(默认快速排序)
* 获取排序比较器(优先获取设置的比较类,没有的话取Writable类型默认的比较器)
* 将keyvalue键值对序列化
* 判断是否启用combiner,如果溢写的小文件数量超过3,则启用combiner合并
* 获取压缩对象
* 开启溢写线程

这里多嘴几句,因为篇幅有限,先写下buffer的一些特性,以后可以在这个类的源码中验证:
* buffer本质还是字节数组
* buffer有赤道的概念,即分界点,一边输入数据,一边输入索引
* 索引:固定宽度:16字节,4个int(partition,keystart,valuestart,valuelenth)
* combiner默认发生在溢写之前,排序之后

#### reduce端源码
我们先看Reducer类的注释,头注释翻译过来大概意思就是<br/>
reducer主要做两件事,一件是拉取shuffle的数据,一件是对数据进行sort,这里的排序不是对数据进行在排序,因为map已经对数据进行过排序了,这里是对map排序过的数据文件进行归并.
好了要点说完了,我们直接看ReudceTask的run方法
其中有一句代码是这样的
```
    RawKeyValueIterator rIter = null;
    ShuffleConsumerPlugin shuffleConsumerPlugin = null;
    shuffleConsumerPlugin.init(shuffleContext);
    ShuffleConsumerPlugin.Context shuffleContext =
      new ShuffleConsumerPlugin.Context(getTaskID(), job, FileSystem.getLocal(job), umbilical,
                  super.lDirAlloc, reporter, codec,
                  combinerClass, combineCollector,
                  spilledRecordsCounter, reduceCombineInputCounter,
                  shuffledMapsCounter,
                  reduceShuffleBytes, failedShuffleCounter,
                  mergedMapOutputsCounter,
                  taskStatus, copyPhase, sortPhase, this,
                  mapOutputFile, localMapFiles);
    shuffleConsumerPlugin.init(shuffleContext);

rIter = shuffleConsumerPlugin.run();
```
最后一句,通过shfulle插件获取迭代器,我们知道基本reduce的数据都是通过迭代器获取的<br/>
#### 迭代器的使用
为什么使用迭代器呢?因为我不可能将数据一次性的装进内存里,最好是通过迭代器维护一个对文件的指针,这样不仅遍历和实现分离,而且谁想要读取这个文件只要生成一个迭代器,维护自己的指针就可以,不会出现强指针或者同一个数据文件占多份内存的情况.
然后我们追踪Reducer的的迭代器类,追踪路径如下
context.getValues().iterator();  -> ReudceContext -> ReduceContextImpl
进入reduce实现类之后最后有一个getValues方法
```
public
Iterable<VALUEIN> getValues() throws IOException, InterruptedException {
  return iterable;
}
```
他返回一个Iterable对象,而Iterable只有一个方法,返回iterator对象
```
private ValueIterator iterator = new ValueIterator();
 @Override
    public Iterator<VALUEIN> iterator() {
      return iterator;
    }
```
而iterator绝对有hasNext对象和next方法(迭代器模式常识)
我们看一下他的hasNext方法
```
@Override
   public boolean hasNext() {
     try {
       if (inReset && backupStore.hasNext()) {
         return true;
       }
     } catch (Exception e) {
       e.printStackTrace();
       throw new RuntimeException("hasNext failed", e);
     }
     return firstValue || nextKeyIsSame;
   }

```
最后有一个boolean值nextKeyIsSame,我们先记住它然后我们看ReducerContextImpl的另一个方法nextkey方法
```
public boolean nextKey() throws IOException,InterruptedException {
    while (hasMore && nextKeyIsSame) {
      nextKeyValue();
    }
    if (hasMore) {
      if (inputKeyCounter != null) {
        inputKeyCounter.increment(1);
      }
      return nextKeyValue();
    } else {
      return false;
    }
  }
```
最后nextKey方法会调用nextkeyValue,这里只给出nextKeyValue的最后一句代码
```
nextKeyIsSame = comparator.compare(currentRawKey.getBytes(), 0,
                                     currentRawKey.getLength(),
                                     nextKey.getData(),
                                     nextKey.getPosition(),
                                     nextKey.getLength() - nextKey.getPosition()
                                         ) == 0;
```
他会他通过判断器进行判断,下一个key是否和现在的key相等,把结果值赋值给nextKeyIsSame,对就是刚刚记住的nextKeyIsSame.
也就是说,我们调用的values.hasNext方法,会判断nextKeyIsSame,下一个key是否相同,不同则返回false,触发reducor再次重新调用reduce方法.
#### 比较器的使用
我们再看一下,ReducerTask的run方法,这里给出关键点
```
RawComparator comparator = job.getOutputValueGroupingComparator();

public RawComparator getOutputValueGroupingComparator() {
    Class<? extends RawComparator> theClass = getClass(
      JobContext.GROUP_COMPARATOR_CLASS, null, RawComparator.class);
    if (theClass == null) {
      return getOutputKeyComparator();
    }

    return ReflectionUtils.newInstance(theClass, this);
  }
```
这个是获取分组比较器的方法,优先使用用户的分组比较器,如果用户的分组比较器为null,则使用默认的key的Writable类型包含的比较器.
而reduce也有排序比较器通过getOutputKeyComparator()获取,
再加上map的排序比较器,我们有三个比较器可以自定义也可取默认的比较器,mapreduce给了我们很灵活的选择取加工数据.
