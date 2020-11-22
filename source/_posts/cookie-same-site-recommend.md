---
title: Cookie 的 SameSite 属性一些资料推荐
date: 2020-11-20 11:40:12
categories: 技术
---
这周推荐一些资料帮忙大家理解 Cookie 的 SameSite 属性是什么，以及如何应对 Chrome 80 Cookie 默认策略的变化，资料按顺序阅读效果更佳。 

![](https://gitee.com/yejinzhan/images/raw/master/20201122132900.jpg)

[《SameSite Cookie Attribute Explained by Example (Strict, Lax, None & No SameSite)》](https://www.youtube.com/watch?v=aUF2QCEudPo)是一个 youtube 短视频，作者实操向我们演示了 SameSite 的三个属性分别有什么不同的效果，非常直观。

[《Cookie 的 SameSite 属性》](https://www.ruanyifeng.com/blog/2019/09/cookie-samesite.html)则先介绍 SameSite 诞生的背景（为了解决 CSRF 攻击问题），接着也对 SameSite 的几个属性做了解释，比前面的视频讲得全面。

[《Chrome 80 跨域 Cookie 变化的影响和应对方案》](https://harttle.land/2020/01/27/secure-cookies.html)则从 Cookie 的构成、Secure 和 SameSite 的关系、Chrome 80 Cookie 策略的变化以及如何应对这些变化的角度来讲述，总体上讲得比较全面，但之前如果没了解过 SameSite，直接看这篇文章的话可能会感觉比较晦涩。我就觉得文末关于旧 Chrome 兼容性解决方案讲得比较晦涩，自己阅读了 [incompatible-clients](https://www.chromium.org/updates/same-site/incompatible-clients) 后，重新梳理了下，兼容方案应该是这样子的：

- 服务端下发两个 Cookie，第一个 Cookie 设置 `Secure` 和 `SameSite=None`，第二个 Cookie 只设置 `Secure`。
- 因为旧版本的 Chrome 会忽略掉第一个 Cookie，所以服务端收到请求取 Cookie 的时候优需要先取第一个 Cookie，如果没有值再取第二个。
