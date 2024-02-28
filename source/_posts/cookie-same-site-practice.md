---
title: Cookie SameSite 支持的最佳实践
date: 2021-03-02 10:18:12
categories: 技术
---
## 背景
正如[Cookie 的 SameSite 属性](https://www.ruanyifeng.com/blog/2019/09/cookie-samesite.html)所说，为了防止 [CSRF](https://developer.mozilla.org/zh-CN/docs/Glossary/CSRF) 攻击，Cookie 的 SameSite 属性用来限制第三方 Cookie，从而减少安全风险。关于 SameSite 的一些基础这里不展开讲，此文主要讲解如何解决 SameSite 策略带来的一些问题。

## Secure
我们先来看两个比较重要的 [Cookie](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Set-Cookie)属性 `Secure` 和 `SameSite`，看看 Chrome Cookie 默认策略的调整对我们的登录有什么影响，以及怎样解决。先来看看 `Secure`。

### 起源
Secure 表示这个 Cookie 只会发送给 HTTPS 的主机，默认没有设置（也就是 insecure）。也就是说如果我的站点同时有 HTTPS 和 HTTP 服务，其中 HTTP 的服务上无法读写 Secure Cookie（避免中间人利用非安全连接伪造 Session）。

### Secure 设置问题
我们简单地做个实验，在 http 响应中设置 `Secure` 属性，因为非 https 请求，设置失败。Chrome 调试面板的响应会有这样的提示：

```
the set-cookies was blocked because it had the “Secure” attribute but was not received over a secure connection。
```

简单翻译就是，cookie 被阻止，因为它具有 Secure 属性，但未通过安全连接接收。所以设置了这个属性后一定要在 https 下进行传输，否则会有问题。

### Cookie 覆盖失败问题
![](https://gitee.com/luobogor/images/raw/master/20211024112609.png)

如上图所示 http 响应中没有设置 `Secure` 属性，但浏览器设置 Cookie 还是失败了，这是为什么呢？Chrome 调试面板的响应会有这样的提示：

```
the set-cookies was blocked because it was not sent over a secure connection and would overwritten a cookie with the secure attribute
```

简单翻译就是浏览器拒收 cookie ，因为这个 cookie 没有在安全通道传输，并且它会覆盖原来带有 secure 属性的 cookie。

案例：我们 A 项目 dev 环境登录偶尔失败，就是这个问题。如果用户已经用 https 的地址登录成功过一次，这种情况下再用 http 地址登录，浏览器不会让非安全通道的 Cookie 覆盖安全通道的 Cookie，所以会拒收这个 Cookie，这是有时候在 http 域名下登录会失败的原因。针对这个问题我们写了个中间件，原理很简单，除本地开发环境其他环境都强制跳转到 https，代码如下：

```js
// express forceHttps 中间件
const _ = require('lodash')
const isServer = process.env.NODE_ENV === 'production'

module.exports = (predicate) => {
  return (req, res, next) => {
    const predicateCheck = !_.isFunction(predicate) || predicate(req)

    if (isServer && req.protocol !== 'https' && predicateCheck) {
      return res.redirect(`https://${req.hostname}${req.originalUrl}`)
    }

    return next()
  }
}
```

## SameSite
### 定义
在了解 SameSite 属性之前，先明确一下一个概念——可注册域（registrable domain）

> A domain's "public suffix" is the portion of a domain that is controlled by a public registry, such as "com", "co.uk", and "pvt.k12.wy.us".  A domain's "registrable domain" is the domain's public suffix plus the label to its left. That is, for "https://www.site.example", the public suffix is "example", and the registrable domain is "site.example".  Whenever possible, user agents SHOULD use an up-to-date public suffix list, such as the one maintained by the Mozilla project at [PSL].

域的「公共后缀」是由公共注册表控制的域的一部分，例如「com」，「co.uk」和「pvt.k12.wy.us」。 域的「可注册域」是该域的公共后缀加上其左侧的标签（也就是公共后缀+1）。即，对于「[https://www.site.example]()」来说，公共后缀为「example」，可注册域为「site.example」。 用户代理应尽可能使用最新的公共后缀列表，例如 Mozilla 项目[\[PSL\]](https://publicsuffix.org/list/public_suffix_list.dat)维护的列表。

> 5.3 The Set-Cookie Header
> 5.3.7. The SameSite Attribute
> A request is "same-site" if its target's URI's origin's registrable domain is an exact match for the request's client's "site for cookies", or if the request has no client. The request is otherwise "cross-site".

如果请求的目标的 URI 的来源的可注册域与请求的客户端的「cookie 站点」完全匹配，或者请求没有客户端，则该请求为「same-site」请求，否则为「cross-site」请求。（译者注：举个简单的例子，比如 a.taobao.com 与 b.taobao.com 的可注册域都为 taobao.com，所以这两个域就是同站的）

> 4.1.2.7. The SameSite Attribute
>
> The "SameSite" attribute limits the scope of the cookie such that it will only be attached to requests if those requests are same-site, as defined by the algorithm in Section 5.2. For example, requests for "https://site.example/sekrit-image" will attach same-site cookies if and only if initiated from a context whose "site for cookies" is "site.example".

「SameSite」属性限制了 cookie 的范围，以便仅当那些请求位于同一站点时才将其附加到请求，如 5.2 节中的算法所定义。例如，对「https://site.example/sekrit-image」的请求将附加且仅当从「cookie 的站点」为「site.example」的上下文中发起时才附加相同站点的 cookie。

> If the "SameSite" attribute's value is "Strict", the cookie will only be sent along with "same-site" requests. If the value is "Lax", the cookie will be sent with same-site requests, and with "cross-site" top-level navigations, as described in Section 5.3.7.1.  If the value is "None", the cookie will be sent with same-site and cross-site requests. If the "SameSite" attribute's value is something other than these three known keywords, the attribute's value will be treated as "None".

如果「SameSite」属性的值为「Strict」，则 Cookie 仅与「same-site」请求一起发送。如果值为「Lax」，则将按照相同站点(same-site)的请求以及「跨站点」顶级导航(top level navigation)发送 cookie，如第 5.3.7.1 节中所述。如果值为「None」，则 cookie 将在 same-site 和 cross-site 发送要求。如果「SameSite」属性的值不同于这三个已知关键字，则该属性的值将被视为「None」。

> The "SameSite" attribute affects cookie creation as well as delivery. Cookies which assert "SameSite=Lax" or "SameSite=Strict" cannot be set in responses to cross-site subresource requests, or cross-site nested navigations. They can be set along with any top-level navigation, cross-site or otherwise.

「SameSite」属性会影响 Cookie 的创建和传输。不能在响应跨站点子资源请求(subresource request)或跨站点嵌套导航的响应中设置断言为「SameSite = Lax」或「SameSite = Strict」的 Cookie（译者注：否则浏览器会拒收 cookie）。可以将它们与任何顶级导航，跨站点或其他方式一起设置。

简单理解 SameSite 属性就是用来做 Cookie 使用范围控制的，不同取值效果不一样，根据网上的一些资料及 Cookie 规范整理如下内容：

- top-level navigation（跳转性质）: 链接、预加载、GET 表单
- subresource request：POST 表单、iframe、ajax、image
- same site（站内请求）：直接在浏览器导航栏输入地址打开网站，或者同站间请求

请求类型	| top-level navigation | subresource request | same site（站内请求）
---|---|---|---
旧浏览器 + 默认设置 | ✔ | ✔ | ✔
Chrome >= 80 + SameSite=Lax（默认）| ✔ | ✖ | ✔
Chrome >= 80 + SameSite=Strict | ✖ |✖ | ✔
Chrome >= 80 + SameSite=None（需求配合 Secure 使用，否则无效） | ✔ | ✔ | ✔

### 问题及解决方案
![](https://gitee.com/luobogor/images/raw/master/20211024110658.png)

问题：
如上图，在管理后台通过 iframe 打开一个非同站的 H5，如果 H5 有响应 cookie，SameSite 默认值为 Lax，浏览器会拒收 Cookie。

解决：
我们 H5 项目有用到 cookie-session，如果不考虑旧版本浏览器兼容，简单地将 SameSite 设成 none 是可以解决问题的。

```js
app.use(cookieSession({
  name: 'fjk-session',
  maxAge: 1000 * 3600 * 24 * 20,
  secret: 'your secret',
  sameSite: 'none',
}));
```

但是后来在比较老的手机碰到[兼容问题](https://www.chromium.org/updates/same-site/incompatible-clients)——在旧版本 Chrome 若存在 sameSite 为 None 的响应，则丢弃这个 Cookie。于是我们参考[Chrome 80 跨域 Cookie 变化的影响和应对方案](https://harttle.land/2020/01/27/secure-cookies.html)的思路写了我们自己的中间件 sameSiteFallbacker。

```js
// *** server.js ***
const cookieName = 'fjk-session'
const cookieSigName = `${cookieName}.sig`
const backCookieNames = [cookieName, cookieSigName]

app.use(sameSiteFallbacker(backCookieNames))

app.use(cookieSession({
  name: cookieName,
  maxAge: 1000 * 3600 * 24 * 20,
  secret: 'your secret',
  sameSite: 'none',
}));

// *** middlewares/same-site-fallbacker.js ***
const _ = require('lodash')
const onHeaders = require('on-headers')

module.exports = (backCookieNames) => {
  return (req, res, next) => {
    onHeaders(res, function setHeaders() {
      const rawCookies = _.chain(res.getHeader('Set-Cookie'))
        .castArray()
        .compact()
        .value()


      if (!rawCookies.length) {
        return
      }

      const backCookies = backCookieNames.map((cookieName) => {
        const cookie = _.find(rawCookies, (item) => {
          return _.startsWith(item, `${cookieName}=`)
        }) || ''

        return cookie.replace(/\s*samesite=none;?/i, '')
          .replace(/\s*;\s*$/, '')
      }) || []


      res.setHeader('Set-Cookie',
        [
          ...backCookies,
          ...rawCookies
        ])
    })

    next()
  }
}
```

原理比较简单，就是在请求结束的时候补一个同名的 cookie 字段，将其中的 sameSite: None 去掉。当 [cookieSession](https://github.com/expressjs/cookie-session#cookie-options) 没有配置 Secure 属性的时候，最终 Secure 的值由当前请求协议决定，HTTPS 则设置 Secure，HTTPS 则不设置。最终组合的结果如下：

-- | HTTPS | HTTP
---|---|---
第一个 Cookie | Secure（兼容老手机） | Secure、SameSite=None 都不设置（兼容 HTTP）
第二个 Cookie | Secure; SameSite=None（解决流行手机 SameSite 问题） | SameSite=None

在有同名 Cookie 的情况下，如果第二个 Cookie 不可用，浏览器会继续检验第一个 Cookie 是否可用，最终效果如下：
![最终效果，下发了两个同名 cookie](https://gitee.com/luobogor/images/raw/master/20211024111809.png)

## 参考
- [Cookie 规范](https://tools.ietf.org/html/draft-ietf-httpbis-rfc6265bis-07)
- [Chrome 80 跨域 Cookie 变化的影响和应对方案](https://harttle.land/2020/01/27/secure-cookies.html)
- [Cookie 的 SameSite 属性](https://www.ruanyifeng.com/blog/2019/09/cookie-samesite.html)
- [SameSite Cookie，防止 CSRF 攻击](https://www.cnblogs.com/ziyunfei/p/5637945.html)
