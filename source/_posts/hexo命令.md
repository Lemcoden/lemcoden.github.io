---
title: hexo命令
date: 2019-12-28 21:14:32
categories: 建站
tags:
    - 博客分享
cover_picture: http://picture.lemcoden.xyz/cover_picture/hexo.jpg
---
1.在个人博客文件夹的/source/_post目录里添加新的md文件，编写格式如下
![编写格式](http://picture.lemcoden.xyz/hexo-update.jpg)
<!-- more -->
2.切换到个人博客的文件夹输入如下命令
```
hexo clean
hexo g
hexo d
```
文章就完整上传了

#### 在hexo环境下创建草稿。

```cpp
 hexo new draft "new draft"
```

会在source/_drafts目录下生成一个new-draft.md文件。但是这个文件不被显示在页面上，链接也访问不到。也就是说如果你想把某一篇文章移除显示，又不舍得删除，可以把它移动到_drafts目录之中。

```
//如果你希望强行预览草稿，更改配置文件：
render_drafts: true

//或者，如下方式启动server：
$ hexo server --drafts

//把草稿变成文章，或者页面：
$ hexo publish [layout] <filename>
```



