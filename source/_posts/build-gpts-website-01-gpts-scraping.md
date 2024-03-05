---
title: GPTS 导航站总结（一）——如何收录GPS
date: 2024-01-27 21:54:28
categories: 建站
---

## 前言
三个月前我上线了一个 GPTs 导航站 —— GptsHappy，本系列文章主要总结过去三个多月自己做了什么，以及给大家介绍如何0到1建站。

概括来说过去三个月主要做了如下事情：

1. 收集了 37284 个GPTS
2. 使用 cloudflare CDN 等方式提高网站访问速度
3. 使用各种策略，优化SEO
4. 接入 Google Search Console、GA4、Clarity Microsoft 等工具跟踪网站流量
5. 到 V2EX、Product Hunt、Reddit 等平台推广

网站流量情况如下：
[图片]
- 被谷歌收条20条
[图片]
- 谷歌流量情况
[图片]

而今天，主要跟大家分享一下很多人最关心的问题，如何收录GPTS。分享一下这个过程自己遇到什么问题，然后是怎样解决的。对于技术人员比较好理解，非技术人员也可以作为借鉴。

## 爬取思路
虽然我是程序员，但也没有做过爬虫。当时也在想怎样收录，到底如何找到数据最根本的源头，然后把这些数据爬取下来。训练营的时候有同学在群里分享过 gpts.works 的资料，我们的项目就是 fork 这个项目的，后来查了一下这个项目最开始的数据源是 gptshunter 分享的。于是顺藤摸瓜找到 gptshunter 作者的一些分享 https://v2ex.com/t/990120
[图片]
大概意思就是，我们爬取 GPTS 的数据可以分为两步：
第一步，利用 Twitter 搜索符合 GPTS 链接格式的帖子，如 https://chat.openai.com/g/g-alKfVrz9K-canva
第二步，请求 GPTS 详情接口，获取单个 GPTS 详细数据
看起来简单，但实际还是有技术难度的。首先第一步，Twitter 页面的搜索功能是不支持通过链接搜索的，这一步不知道 gptshunter 作者是怎样做到的，如果有人知道可以评论哈。当然，网上还有很多人提到可以在谷歌搜索 site:chat.openai.com/g/ ，过滤出 gpts 链接。没错谷歌确实会告诉你它收录了10几万条数据，但实际上你可以浏览的也就只有前10几页，再往下滑你会发现到底了，滑不动了。
[图片]
连 gpshunter 作者都在这种帖子下面推广一波。
[图片]
再到第二步，GPTS 详情接口是有做了反爬的，直接请求是请求不了的（后来作者在上面帖子留言如何绕过反爬）。攻克这些问题对于我来说是有时间成本的，当时的想法是别管那么多，先想办法搞几万条数据，让网站看起来有模样，再慢慢优化。于是决定尝试另一个方法，去爬别人导航站数据。
爬取别的导航站数据
说干就干，于是网上收集了一些GPTS导航网站，整理了一个表格。
[图片]
其中有一些网站是没有做反爬的，非常容易爬取，写一个小脚本，不断请求，一会儿就可以把它的所有数据拿下。就这样我的网站收录了差不多3万数据。

```js
const axios = require('axios');
const path = require('path');
const fs = require('fs');
const req = (last_id, start) => {
  axios.get('
autolinkhttps://www.gpts.fan/api/storeautolink
', {
    params: {
      last_id,
      page_size: 1000,
    }
  })
    .then(response => {
      const resultDirPath = path.join(__dirname, './gptsfan-result')
      const targetPath = 
${resultDirPath}/${start}.json
      const nextId = response.data.rows[response.data.rows.length - 1].id
      fs.writeFileSync(targetPath, JSON.stringify(response.data));
      console.log('成功:', start);
      setTimeout(() => {
        req(nextId, ++start)
      }, 1000)
    })
    .catch(error => {
      console.error('错误:', error);
      setTimeout(() => {
        console.log('重试........................')
        req(start)
      }, 3000)
    });
}

req(0, 1)
```
