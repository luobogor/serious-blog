---
title: 0 到 1 搭建 GPTs 导航站（一）：如何收录 GPTs
date: 2024-03-06 20:54:28
categories: 建站
---

![广州海珠湿地公园](/images/build-gpts-website-01-gpts-scraping/cover.jpg)

0 到 1 搭建 GPTs 导航站系列：
- [0 到 1 搭建 GPTs 导航站（一）：如何收录 GPTs](https://luobogor.gitee.io/2024/03/06/build-gpts-website-01-gpts-scraping/)
- [0 到 1 搭建 GPTs 导航站（二）：Cloudflare CDN 性能优化](https://luobogor.gitee.io/2024/03/07/build-gpts-website-02-cloudfare-cdn/)
- [0 到 1 搭建 GPTs 导航站（三）：SEO 优化](https://luobogor.gitee.io/2024/03/08/build-gpts-website-03-seo-optimization/)
- [0 到 1 搭建 GPTs 导航站（三）：SEO 优化](https://luobogor.gitee.io/2024/03/11/build-gpts-website-04-marketing/)
- [0 到 1 搭建 GPTs 导航站（四）：网站推广](https://luobogor.gitee.io/2024/03/11/build-gpts-website-04-marketing/)

## 前言
出海小白第一次做网站，三个月前我上线了一个 GPTs 导航站 —— [GPTs Happy](https://gptshappy.tools?utm_source=luobogor.gitee.io)，本系列文章主要总结过去三个多月自己做了什么，以及给大家介绍如何 0 到 1 建站。

概括来说过去三个月主要做了如下事情：

1. 学习爬虫，收集了 3w 个 GPTs
2. 使用 cloudflare CDN 等方式提高网站访问速度
3. 使用各种策略，优化SEO
4. 接入 Google Search Console、GA4、Clarity Microsoft 等工具跟踪网站流量
5. 到 V2EX、Product Hunt、Reddit 等平台推广

网站运营情况如下：
- 被谷歌收条 2.7w 条
![google-result.png](/images/build-gpts-website-01-gpts-scraping/img1.png)

- 流量，100 多个人访问过
![google-analytics.png](/images/build-gpts-website-01-gpts-scraping/img2.png)

而今天，主要跟大家分享一下很多人最关心的问题，如何搭建网站和收录 GPTs。分享一下这个过程自己遇到什么问题，然后是怎样解决的。对于技术人员比较好理解，非技术人员也可以作为借鉴。

## 项目搭建
直接用 [gpts.works](https://github.com/all-in-aigc/gpts-works) ，按照文档部署到 Vercel 使用即可，超方便。

## 爬取推特 GPTs 搜索结果
虽然我是干开发的，但也没有做过爬虫。当时也在想怎样收录，到底如何找到数据最根本的源头，然后把这些数据爬取下来。网上查到 [GPTs Works](https://gpts.works?utm_source=luobogor.gitee.io) 初期的数据源是 [GPTs hunter](https://www.gptshunter.com?utm_source=luobogor.gitee.io) 分享的。于是顺藤摸瓜找到 GPTs hunter 作者的一些[分享](https://v2ex.com/t/990120)： 

![v2ex.png](/images/build-gpts-website-01-gpts-scraping/img3.png)

于是按着 GPTs hunter 作者的思路写了两个爬虫脚本，大家可以直接拿去用：

1. [从推特上爬取 GPTs 链接](https://github.com/luobogor/twitter-gpts-crawler)
2. [从 ChatGpt 上爬取 GPTs 详情](https://github.com/luobogor/gpts-detail-crawler)

## 爬取谷歌 GPTs 搜索结果
当然，网上还有很多人提到可以在谷歌搜索 site:chat.openai.com/g/ ，过滤出 GPTs 链接。

![google-result2.png](/images/build-gpts-website-01-gpts-scraping/img4.png)

研究了一下谷歌搜索，如果自己写脚本请求翻页可以这样搞 `https://google.com/search?q=Query&num=10&start=0` 。但是会有两个问题，第一是速率太快会被会被弹人机验证，所以别请求太快。另一个就是，谷歌虽然告诉你它收录了 49 万条数据，但实际上你可以浏览的也就只有前 10 几页，再往下滑你会发现到底了，滑不动了，用接口请求也会有同样的问题。

在搜索 API 加上时间参数，限制搜索时间就可以解决这个问题。完整 API 参数如下：

```
https://google.com/search?q=Query&num=10&start=0&tbs=encodeURIComponent(cdr:1,cd_min:1/1/2024,cd_max:1/2/2024)
```
