---
title: 0 到 1 搭建 GPTs 导航站（二）：Cloudflare CDN 性能优化
date: 2024-03-07 20:54:28
categories: 建站
---

<img src="/images/build-gpts-website-02-cloudfare-cdn/cover.jpg" width = "500" alt="恩平市恩湖路" />

0 到 1 搭建 GPTs 导航站系列：
- [0 到 1 搭建 GPTs 导航站（一）：如何收录 GPTs](https://luobogor.gitee.io/2024/03/06/build-gpts-website-01-gpts-scraping/)
- [0 到 1 搭建 GPTs 导航站（二）：Cloudflare CDN 性能优化](https://luobogor.gitee.io/2024/03/07/build-gpts-website-02-cloudfare-cdn/)
- [0 到 1 搭建 GPTs 导航站（三）：SEO 优化](https://luobogor.gitee.io/2024/03/08/build-gpts-website-03-seo-optimization/)
- [0 到 1 搭建 GPTs 导航站（四）：网站推广](https://luobogor.gitee.io/2024/03/11/build-gpts-website-04-marketing/)

今天给大家介绍如何让自己的 GPTs 导航站接入 Cloudflare CDN，让网站秒开，提升用户体验。

## 接入 CDN
不同国家访问你的网站距离是不一样的，远的就会慢。使用 CDN 可以保证不同国家访问你网站的速度一样快。cloudflare 官网可以看到，他们家的 CDN 是免费的，白嫖起来！

![img.png](/images/build-gpts-website-02-cloudfare-cdn/img.png)

[Cloudflare 注册](https://dash.cloudflare.com/sign-up) 后进入主界面，点击「Add a site」

![img_1.png](/images/build-gpts-website-02-cloudfare-cdn/img_1.png)

输入你的域名，点击「Continue」

![img_2.png](/images/build-gpts-website-02-cloudfare-cdn/img_2.png)

选 Free 的套餐，再点击「Continue」

![img_3.png](/images/build-gpts-website-02-cloudfare-cdn/img_3.png)

一路继续到第三步

![img_4.png](/images/build-gpts-website-02-cloudfare-cdn/img_4.png)

往下拉会看到两个 nameserver，然后将你域名 DNS 的 nameserver 改成这两个 nameserver 就可以。

![img_5.png](/images/build-gpts-website-02-cloudfare-cdn/img_5.png)

这里我用 GoDaddy 演示，进入 DNS 管理界面的 Nameservers，点击 「Change Nameservers」，修改完成后回到 cloudflare 点击 「Continue」。

![img_6.png](/images/build-gpts-website-02-cloudfare-cdn/img_6.png)

等几小时 DNS 解析生效后，你的网站就接入 CDN 成功了。

## 测试 CDN
使用[站长之家](https://ping.chinaz.com/) ping 一下，如果独立 IP 大于 1 个，说明接入 CDN 成功了。

![img_7.png](/images/build-gpts-website-02-cloudfare-cdn/img_7.png)
![img_8.png](/images/build-gpts-website-02-cloudfare-cdn/img_8.png)

测速一下，还可以。

![img_9.png](/images/build-gpts-website-02-cloudfare-cdn/img_9.png)

是不是很简单呢小伙伴们？赶紧用起来吧！
