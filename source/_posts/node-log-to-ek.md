---
title: Node.js 日志上报到 Elasticsearch、Kibana 实战
date: 2022-12-05 00:25:12
categories: 技术
---

## 背景

阅读本文只需要懂一点点 Node，Elasticsearch 零基础、Kibana 零基础，都没有问题。Elasticsearch 有多个版本，本文以 7.17 为例进行讲解。Kibana 帮助我们用可视化的方式进行 Elasticsearch 查询。


## 安装
下面涉及到安装的步骤都以 MacOS 为例进行讲解，其他操作系统可以参考 [《Set up Elasticsearch》](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/targz.html) 进行操作。

参考 ES 文档 https://www.elastic.co/guide/en/elasticsearch/reference/7.17/brew.html，执行以下命令安装 Elasticsearch

```shell
brew tap elastic/tap
brew install elastic/tap/elasticsearch-full
```

安装完成后，执行控制台执行 `elasticsearch` 命令启动 ES，启动后如何能正常访问 [http://localhost:9200](http://localhost:9200) 表示启动成功。[全文搜索引擎 Elasticsearch 入门教程](https://www.ruanyifeng.com/blog/2017/08/elasticsearch.html)

```shell
$ curl http://localhost:9200
{
  "name" : "jinzhanyedeMacBook-Pro.local",
  "cluster_name" : "elasticsearch_jinzhanye",
  "cluster_uuid" : "U4ob5U_CQXifCe_FgI183A",
  "version" : {
    "number" : "7.17.4",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "79878662c54c886ae89206c685d9f1051a9d6411",
    "build_date" : "2022-05-18T18:04:20.964345128Z",
    "build_snapshot" : false,
    "lucene_version" : "8.11.1",
    "minimum_wire_compatibility_version" : "6.8.0",
    "minimum_index_compatibility_version" : "6.0.0-beta1"
  },
  "tagline" : "You Know, for Search"
}
```

参考 [ES Kibana 文档](https://www.elastic.co/guide/en/kibana/7.17/brew.html#brew-layout)，执行以下命令安装 Kibana。

```shell
$ brew tap elastic/tap
$ brew install elastic/tap/kibana-full
```

安装完成后，并确定 Elasticsearch 已经启动成功后，控制台执行 `kibana` 命令启动 Kibana。启动后如何能正常访问 [http://localhost:5601](http://localhost:5601) 表示启动成功。

![img.png](img2.png)


至此我们已经环境搭建完毕，在进入下一小节之前如果之前没有接触过 ES，可以看看阮老师的文章 [《全文搜索引擎 Elasticsearch 入门教程》](https://www.ruanyifeng.com/blog/2017/08/elasticsearch.html) 简单了解一下，有利于消化后面的内容。阮老师文章里提到的命令也可以在 [Kibana Dev Tools](http://localhost:5601/app/dev_tools#/console) 执行，内容被格式化后阅读体验更佳。

## Node 日志上报 

## 参考 

---

欢迎关注我的公众号 Luobo FE，获取最新资讯动态🔥

![](/images/common/qrcode.jpg)
