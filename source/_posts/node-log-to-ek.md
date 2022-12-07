---
title: Node.js、Elasticsearch、Kibana 日志上报实战
date: 2022-12-05 00:25:12
categories: 技术
---

## 背景
要使用日志查询服务可以直接购买云厂商的，比如阿里云的 SLS、腾讯云的 CLS。 如果要自己实现日志上报，一般做法是这样的：
- 用 Filebeat 从文件收集日志做日志过滤、清洗。
- Filebeat 处理后的日志发送到 Kafka 削峰处理。
- Logstash 从 Kafka 读取日志存储到 Elasticsearch（以下简称 ES）。
- 开发者在 Kibana 进行日志查询。

![](/images/node-log-to-ek/img6.png)

我们团队目前的需求是把内部 Node 服务日志上报到 ES，流量不大，所以采用简单的做法。Node 直接将日志存储到 ES，使用 Kibana 用可视化的方式进行 ES 查询日志。

![](/images/node-log-to-ek/img7.png)

接下来将为大家介绍如何搭建这个架构，如何封装用户体验良好的 Node 日志上报 SDK。ES 有多个版本，本文以 7.17 为例进行讲解。

## 安装 ES、Kibana
下面涉及到安装的步骤都以 MacOS 为例进行讲解，其他操作系统可以参考 [《Set up Elasticsearch》](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/targz.html) 进行操作。执行以下命令安装 ES。

```shell
$ brew tap elastic/tap
$ brew install elastic/tap/elasticsearch-full
```

安装完成，在控制台执行 `elasticsearch` 命令启动 ES，启动后如果能正常访问 [http://localhost:9200](http://localhost:9200) 表示启动成功。

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

执行以下命令安装 Kibana。

```shell
$ brew tap elastic/tap
$ brew install elastic/tap/kibana-full
```

安装完成，并确定 ES 已经启动成功后，控制台执行 `kibana` 命令启动 Kibana。启动后如何能正常访问 [http://localhost:5601](http://localhost:5601) 表示启动成功。

![](/images/node-log-to-ek/img2.png)

至此我们已经把环境搭建完毕，在进入下一小节之前如果之前没有接触过 ES，可以看看阮老师的文章 [《全文搜索引擎 Elasticsearch 入门教程》](https://www.ruanyifeng.com/blog/2017/08/elasticsearch.html) 简单了解一下，有利于消化后面的内容。阮老师文章里提到的命令也可以在 [Kibana Dev Tools](http://localhost:5601/app/dev_tools#/console) 执行，内容被格式化后阅读体验更佳。


## Node 日志上报到 ES  
Node 日志上报到 ES 参考这个 [Demo](http.baidu.com)，我们使用 [winston](https://www.npmjs.com/package/winston) 打印日志，使用 [winston-elasticsearch](https://www.npmjs.com/package/winston-elasticsearch) 上报日志到 ES。如下面代码配置所示 winston-elasticsearch 每天新建一个命名为 simple-es-logger-demo-YYYY.MM.DD 的 index。

```js
/**
 * es-logger.js
 */

const { createLogger: createWinstonLogger, transports, format } = require('winston')
const { ElasticsearchTransport } = require('winston-elasticsearch')

const esNode = 'http://localhost:9200'

function createLogger() {
  return createWinstonLogger({
    level: 'info',// 只上报 info 级别以上日志，包括 info、warn、error
    transports: [
      new transports.Console({// 输出到控制台
        format: format.json(),
      }),
      new ElasticsearchTransport({// 输出到 ES
        indexPrefix: 'simple-es-logger-demo',// ES index 前缀
        indexSuffixPattern: 'YYYY.MM.DD',// ES index 后缀，跟前缀拼接起来 index 最终就是 simple-es-logger-demo-YYYY.MM.DD，如 simple-es-logger-demo-2023.01.12
        clientOpts: {
          node: esNode,
          maxRetries: 5,
          requestTimeout: 10000,
          sniffOnStart: false,
        },
      })
    ]
  })
}

module.exports = createLogger()
```

> Compatibility For Winston 3.7, Elasticsearch 8.0 and later, use the >= 0.17.0. For Winston 3.4, Elasticsearch 7.8 and later, use the >= 0.16.0. For Winston 3.x, Elasticsearch 7.0 and later, use the >= 0.7.0. For Elasticsearch 6.0 and later, use the 0.6.0. For Elasticsearch 5.0 and later, use the 0.5.9. For earlier versions, use the 0.4.x series.

这里版本的问题需要注意，我们使用的是 ES 7.17，从 winston-elasticsearch 的文档可以得知，winston 需要选择 3.4 版本， winston-elasticsearch 需要选择 >= 0.16.0 的版本。

```json5
// package.json
"dependencies": {
  "koa": "^2.5.2",
  "winston": "3.4.0",
  "winston-elasticsearch": "0.16.1"
},
```

接着我们用 Koa 搭建一个简单的服务。

```js
/**
 * index.js
 */

const Koa = require('koa')
const app = new Koa()
const logger = require('./es-logger')


app.use(async (ctx, next) => {
  const body = {
    message: `服务被访问了，生成随机数：${ Math.floor(Math.random() * 100) }`
  }

  logger.info(JSON.stringify(body))

  ctx.body = body

  next()
})

const port = 7115

app.listen(port, () => {
  console.log(`服务启动成功，http://localhost:${7115}`)
})
```

访问 [http://localhost:7115](http://localhost:7115)，控制台输出如下。

```
$ curl http://localhost:7115
{"level":"info","message":"{\"message\":\"服务被访问了，生成随机数：14\"}"}
```

如果你的控制台没有报错，说明日志已经上报到 ES。winston-elasticsearch 将日志格式化成这样再进行发送。

```
{
  "@timestamp": "2022-12-07T06:19:24.969Z",
  "message": "{\"message\":\"服务被访问了，生成随机数：14\"}",
  "severity": "info",
  "fields": {}
}
```

接下来我们看看如何使用 Kibana 查看我们上报的日志。

## 使用 Kibana 查看日志
在首页左侧面板导航找到 Management -> Stack Management，点击进入 Stack Management。再在左侧导航找到 [Index Patterns](http://localhost:5601/app/management/kibana/indexPatterns)。Name 输入 `simple-es-logger-demo-*`，过滤以 `simple-es-logger-demo` 开头的 index。Timestamp field 选择 @timestamp。

![](/images/node-log-to-ek/img3.png)

在首页左侧面板导航找到 Discovery，选择过滤 `simple-es-logger-demo-*`，就可以看到我们上报的日志。

![](/images/node-log-to-ek/img4.png)

我们还可以使用 KQL 语法根据关键字过滤日志，比如输入 `message: "14"` 过滤 `message` 字段包含 `14` 的日志。

![](/images/node-log-to-ek/img5.png)

## 封装更好用的 SDK
上文简单封装的 SDK 是不足以应对实际生产环境的，结合实际业务遇到的问题，我们封装了内部使用的日志上报 SDK，欢迎 Start & Fork。

- @za-node/express-logger：Express 日志上报 SDK。
- @za-node/koa-logger：Koa 日志上报 SDK。
- @za-node/egg-framework：基本 Egg 封装的简单上层框架，主要集成日志上报功能。

主要解决了如下问题：

- ctxLogger API：在实际生产环境中，除了打印的内容以外我们通常还需要记录更多请求上下文信息，比如本次请求的用户的信息、请求耗时、请求 id、请求方法、请求路由、响应体等等。
- 自动上报请求、上报响应中间件：自动记录每个请求、响应信息。
- 性能问题：非 Serverless 环境先缓存日志，每 30s 上报一次。
- Serverless 环境支持：我们团队有些项目已经迁移到 Serverless 环境部署，Serverless 环境请求结束就会马上销毁服务实例。针对这种情况，在请求结束前 SDK 会完成日志上报，保证日志不丢失。
- 更好的 API 体验：
  - SDK 内部使用 [json-stringify-safe](https://www.npmjs.com/package/json-stringify-safe) 将对象进行序列化，保证不会出现序列化异常。
  - 针对 Error 对象做特殊序列化处理，提高错误信息可读性。

## 参考
- [Elasticsearch 官方文档](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/targz.html)
- [全文搜索引擎 Elasticsearch 入门教程](https://www.ruanyifeng.com/blog/2017/08/elasticsearch.html)
- [winston](https://www.npmjs.com/package/winston)
- [winston-elasticsearch](https://www.npmjs.com/package/winston-elasticsearch)
- [json-stringify-safe](https://www.npmjs.com/package/json-stringify-safe)

---

欢迎关注我的公众号 Luobo FE，获取最新资讯动态🔥

![](/images/common/qrcode.jpg)
