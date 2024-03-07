---
title: 0 到 1 搭建 GPTs 导航站（二）：Cloudflare CDN 性能优化
date: 2024-03-08 20:54:28
categories: 建站
---

![广州海珠湿地公园](/images/build-gpts-website-03-seo-optimization/cover.jpg)

0 到 1 搭建 GPTs 导航站系列：
- [0 到 1 搭建 GPTs 导航站（一）：如何收录 GPTs](https://luobogor.gitee.io/2024/03/06/build-gpts-website-03-seo-optimization/)
- [0 到 1 搭建 GPTs 导航站（二）：Cloudflare CDN 性能优化](https://luobogor.gitee.io/2024/03/07/build-gpts-website-02-cloudfare-cdn/)

文本介绍几个做 GPTs 导航站时实践过的 SEO 优化技巧：
1. 提交 sitemap 文件
2. 内链建设
3. 服务端渲染
4. 网页路径命名优化
5. 收录热门内容

## 提交 sitemap文件
你可以将网站内容地址输出到 sitemap.xml，然后提交到 Google Search Console 让谷歌去收录。sitemap.xml 结构如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
      <loc>https://gptshappy.tools/your-heartfelt-speech-writer-g-MK1x3Mw7n</loc>
  </url>
  <url>
      <loc>https://gptshappy.tools/emoji-creator-translator-generator-g-hSCFYkgE7</loc>
  </url>
  <url>
      <loc>https://gptshappy.tools/create-connections-game-g-tBwt5hDMI</loc>
  </url>
  .......
</urlset>  
```

将文件部署到线上，然后提交到 Google Search Console，状态显示「成功」表明谷歌成功访问这个文件了。

![img.png](/images/build-gpts-website-03-seo-optimization/img.png)

sitemap 提交后并不代表谷歌会收录你的内容，只能说谷歌发现了你的内容。可以看到下面这个页面已经被谷歌发现但并没有收录。

![img_1.png](/images/build-gpts-website-03-seo-optimization/img_1.png)

我们只需要保证该页面能正常被谷歌爬虫访问即可，当谷歌认为你的内容质量没有问题就会进行收录。那么如何知道自己的页面能否正常被谷歌访问呢？在网站检查详情页，点击「测试实际版本」->「查看被测试的见面」->「屏幕截图」，如果页面能正常显示，说明网页正常。

![img_2.png](/images/build-gpts-website-03-seo-optimization/img_2.png)

## 内链建设
内链建设是指网站内任何两个网页能通过链接到达。如下图所示，用户从首页进入详情页，点击顶部 Logo 可以回到首页，点击底部「Other GPTs you may like」区域可以继续访问其他 GPTS。谷歌爬虫亦是如此，从一个链接开始一直往下爬。

![img_3.png](/images/build-gpts-website-03-seo-optimization/img_3.png)

回到 Google Search Console，可以看到收录的这个网页是从另一个站内网页引荐过来的。说明上面「Other GPTs you may like」的内链确实起到了作用。

![img_4.png](/images/build-gpts-website-03-seo-optimization/img_4.png)

## 服务端渲染
服务端渲染是指网站响应的 html 内容已经生成好再返回，如下图。

![img_5.png](/images/build-gpts-website-03-seo-optimization/img_5.png)

而不是像下面这个网站这样，在浏览器进行渲染。

![img_6.png](/images/build-gpts-website-03-seo-optimization/img_6.png)

## 网页路径命名优化
网页路径的命名可以影响谷歌（以及其他搜索引擎）的 SEO，包含关键字可以提高页面的相关性。本来的 URL 命名是这样的 https://gptshappy.tools/g-hSCFYkgE7，参考 GPTs Works 后修改成了这样
[https://gptshappy.tools/emoji-creator-translator-generator-g-hSCFYkgE7](https://gptshappy.tools/emoji-creator-translator-generator-g-hSCFYkgE7)，将 GPTs 的命名加上去。

## 收录热门内容
热门的 GPTs 肯定是最多人搜索的，首页放置热门的 GPTs 有利于谷歌展示你的网站。
