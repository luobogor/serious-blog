---
title: cookie-session 源码解读
date: 2021-02-21 10:55:12
categories: 技术
---

## 背景
前一段时间在修复因为 Chrome 升级新版本后 [SameSite](https://web.dev/samesite-cookies-explained/) 属性设置不当导致 Cookie 失效的问题，主要是编写中间件对 Cookie 进行处理。而有其中一个项目是使用 [cookie-session](https://github.com/expressjs/cookie-session) 设置 Cookie 的，为了在这个项目处理 SameSite 这个问题，于是就翻看了这个库的源码。

## 关于 JWT（JSON Web Token）
正如 [JSON Web Token 入门教程](https://www.ruanyifeng.com/blog/2018/07/json_web_token-tutorial.html)里面所提到的那样，Session 有两种存储方式，一种解决方案是 Session 保存在服务端；另一种方案是保存在客户端，每次请求都发送回服务器，JWT 就是这种方案的一个代表，各有利弊。JWT 方案本身并不复杂，需要注意的是要搞清楚签名与加密的区分。签名是为了防篡改，不是防信息泄漏，因为 JWT 前两部分是 Base64URL 转码后的数据，所以 Header、Payload 是可以使用浏览器的 [btoa](https://developer.mozilla.org/zh-CN/docs/Web/API/WindowBase64/Base64_encoding_and_decoding) 方法转换查看原文的。

对于 [Express](https://github.com/expressjs/express) 来说，代表第一种方案的第三方库有 [express-session](https://github.com/expressjs/session)，代表第二种方案的第三方库有 [cookie-session](https://github.com/expressjs/cookie-session)，本文主要介绍 cookie-session 的实现原理，本文源码解读基于 2.0.0-rc.1 版本。

## 一些概念
### JWT
一个防篡改的身份验证标准。

### Cookie
客户端保存用户数据的一种方式。

### Session
服务端保存用户态的结构，依赖服务端存储，服务端从 Cookie 中获取 sid，再通过 sid 从持久层中查询数据。

### cookie-session
一个第三方库，设计思想跟 JWT 相似，用户态不依赖服务端存储，服务端响应时设置整个 Session 对象到 Cookie，服务端接收到请求的时候直接从 Cookie 中获取整个 Session 对象，不依赖服务端存储用户数据。也可以使用签名防止客户端篡改数据。跟 JWT 没有强关联关系，使用 cookie-session 的时候，开发者可以在 Session 对象存储任何可序列化的数据结构。而 JWT 也并不依赖 cookie-session 实现。

## cookie-session 实现原理
### 整体流程
开篇先整体讲下接收到请求和请求结束时发生了什么事情，有助于大家理解接下来要讲的代码细节。可以结合这个 [Demo](https://github.com/jinzhanye/cookie-session-demo) 一起理解本文。

cookie-session 底层是依赖 [cookies](https://github.com/pillarjs/cookies) 实现的，以下面的请求为例，请求进入服务时，cookie-session 调用 Cookie.get 从请求头中读取 Cookie（my-session），以及读取该 Cookie 的签名(my-session.sig)，并校验签名是否合法。如果是合法则将该 Cookie 字符串返回给 cookie-session，cookie-session 再将该串反序列化成一个 Session 对象。拿到 Session 对象后开发者可以对 Session 进行一些操作。

```
GET / HTTP/1.1
Host: 192.168.2.200:3900
Connection: keep-alive
Cache-Control: max-age=0
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.141 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9
Accept-Encoding: gzip, deflate
Accept-Language: zh-CN,zh;q=0.9,en;q=0.8
Cookie: my-session=eyJ0b2tlbkEiOiJmb28iLCJ0b2tlbkIiOiJiYXIifQ==; my-session.sig=8IJIgYrEoLp0MvJma_LtT2YjDKY
If-None-Match: W/"a-nttZqUcoAe3sTHxhbDDKjwEcT4U"
```

以下面响应为例，请求将要结束时，cookie-session 将当前的 Session 实例进行序列化，再调用 Cookie.set 设置两个 Cookie，一个是序列化后的 session 实例（my-session），另一个是该 Cookie 的签名，也就是 Demo 响应里以 .sig 结尾的 Cookie（my-session.sig）。

```
HTTP/1.1 200 OK
X-Powered-By: Express
Set-Cookie: my-session=eyJ0b2tlbkEiOiJmb28iLCJ0b2tlbkIiOiJiYXIifQ==; path=/; expires=Sun, 21 Feb 2021 07:25:24 GMT; httponly
Set-Cookie: my-session.sig=8IJIgYrEoLp0MvJma_LtT2YjDKY; path=/; expires=Sun, 21 Feb 2021 07:25:24 GMT; httponly
Date: Mon, 01 Feb 2021 07:25:24 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 10
ETag: W/"a-nttZqUcoAe3sTHxhbDDKjwEcT4U"
```

### 入口
```js
function cookieSession (options) {
  var opts = options || {}
  
  // cookie name
  var name = opts.name || 'session'
  
  // secrets
  var keys = opts.keys
  if (!keys && opts.secret) keys = [opts.secret]
  
  // defaults
  if (opts.signed == null) opts.signed = true
  if (!keys && opts.signed) throw new Error('.keys required.')
  // ....
  
  return function _cookieSession (req, res, next) {}
}
```

先来看 `cookieSession` 这个方法，也就是这个库的入口做了什么事情。首先是保证在开启签名选项 `signed` 的情况下开发者传入的 options 的 `keys` 或 `secret` 其中一个必须存在，因为后续签名要使用，然后就是返回一个中间件 `_cookieSession`。

```js
function _cookieSession(req, res, next) {
  var cookies = new Cookies(req, res, {
    keys: keys
  })
  var sess

  // for overriding
  req.sessionOptions = Object.create(opts)

  // define req.session getter / setter
  Object.defineProperty(req, 'session', {
    configurable: true,
    enumerable: true,
    get: getSession, // 读取 req.session 或 req.session.xxx 时触发
    set: setSession // 赋值 req.session 时触发
  })

  function getSession() {
    // already retrieved
    if (sess) {
      return sess
    }

    // get session
    if ((sess = tryGetSession(cookies, name, req.sessionOptions))) {
      return sess
    }
    // ...
    return (sess = Session.create())
  }

  function setSession(val) {
    // ...
    if (typeof val === 'object') {
      // create a new session
      sess = Session.create(val)
      return sess
    }
    // ...
  }

  onHeaders(res, function setHeaders() {
    if (sess === undefined) {
      // not accessed
      return
    }

    // ....
    cookies.set(name, Session.serialize(sess), req.sessionOptions)
  })

  next()
}
```

`_cookieSession` 的主干逻辑并不复杂，50 行左右的代码。从代码可以看到，`req` 上绑定了一个 Session 实例供开发者使用，整体可以分两个流程，一个是请求进来时读取 Cookie，也就是 `getSession` 的逻辑。另一个设置 Cookie，其中包括开发者设置 Cookie 时调用的 `setSession` 逻辑，以及请求结时触发的 `onHeaders` 逻辑。而这些逻辑的底层都是依赖于第三库 `Cookies` 的 `get` 与 `set` 方法实现，这两个方法的内部实现讲完整体流程后再讲述。

### 读取 Cookie
先讲一下从请求头中读取 Cookie 的逻辑，也就是 `getSession`。当开发者读取 session 信息，比如以下代码

```js
const tokenA = req.session.tokenA

// 或者（这种写法先是触发 getter，再是触发 setter）
req.session.tokenA = 'foo'
```

就会触发 `req.session` 的 getter 方法，也就是调用 `getSession`，`getSession` 调用 `tryGetSession`

```js
function tryGetSession (cookies, name, opts) {
  var str = cookies.get(name, opts)

  if (!str) {
    return undefined
  }

  //...
  return Session.deserialize(str)
}

 function getSession() {
   // already retrieved
   if (sess) {
     return sess
   }

   // get session
   if ((sess = tryGetSession(cookies, name, req.sessionOptions))) {
     return sess
   }
   // ...
   return (sess = Session.create())
 }
```

最终调用 `Cookies.get` 从请求头中读取 Cookie，当请求头中没有 Cookie 的时候，也就是用户第一次访问网站的时候, `getSession` 会调用 `Session.create` 创建 `Session` 实例。现在我们先来看看 `Session` 的类设计，当请求头存在 Cookie 走 `Session.deserialize` 逻辑后面讲。 

```js
Session.create = function create (obj) {
  var ctx = new SessionContext()
  return new Session(ctx, obj)
}

function Session (ctx, obj) {
  Object.defineProperty(this, '_ctx', {
    value: ctx
  })

  if (obj) {
    for (var key in obj) {
      this[key] = obj[key]
    }
  }
}

function SessionContext () {
  this._new = true
  this._val = undefined
}
```

从上面代码可以看到，最终构造出来的 `Session` 实例是这样子的

```js
const sess = {// Session
  tokenA: 'foo',
  tokenB: 'bar',
  // .... 开发者可以添加多个 key
  _ctx: { // SessionContext
    _new: Boolean, // 是否为新的 SessionContext
    _value: String, // 经过 Base64 编码序列化后的 Session 实例，以 Demo 为例就是 base64Encode(JSON.stringify({ tokenA: 'foo', tokenB: 'bar' }))
  }
}
```

`_ctx` 是个 `unenumerable` 属性，所以 `_ctx` 是不会被 `JSON.stringify` 转换。`_new` 表示
Session 实例是否通过 `Session.create` 创建的实例。`Session.create` 被调用的时机有两个，一个是上文提到的用户首次访问的情况；另一个是当开发者以整个对象的形式赋值 session（也就是 `req.session = { /*....*/ }` ）。

上文提到过如果是请求头中存在 Cookie，会通过 `Session.deserialize` 创建 `Session` 实例，这时 `_new` 为 `false`。而 _value 则是 `Cookie.get` 获取的值。 _value 逆 Base64 解码后可以得到一个 `Session` 实例。以下为 `Session.deserialize` 创建的 Session 对象：

```js
const sess = {// Session
  tokenA: 'foo',
  tokenB: 'bar',
  _ctx: { // SessionContext
    _new: false, // 
    _value: 'eyJ0b2tlbkEiOiJmb28iLCJ0b2tlbkIiOiJiYXIifQ==', // 经过 Base64 编码后的值，也就是 base64Encode(JSON.stringify({ tokenA: 'foo', tokenB: 'bar' }))
  }
}

Session.deserialize = function deserialize (str) {
  var ctx = new SessionContext()
  var obj = decode(str)

  ctx._new = false
  ctx._val = str

  return new Session(ctx, obj)
}

function decode (string) {
  var body = Buffer.from(string, 'base64').toString('utf8')
  return JSON.parse(body)
}
```
 
### 设置 Cookie
`onHeaders` 的回调会在请求将要结束时被调用，`Cookie.set` 将经过 `JSON.stringify` 及 Base64 编码后的字符串设置到响应头中，同时加上签名。

```js
Session.serialize = function serialize (sess) {
  return encode(sess)
}

function encode (body) {
  var str = JSON.stringify(body)
  return Buffer.from(str).toString('base64')
}
```

顺便看下 [onHeader](https://github.com/jshttp/on-headers "onHeader") 的源码，逻辑并不复杂。请求结束时 Express 内部调用 Node 原生的 `res.end` 方法，而 `res.end` 内部会调用 `res.writeHeader`，`onHeaders` 对 `res.writeHead` 进行了简单的重写，使得开发者可以监听 `res.writeHead`。

```js
function onHeaders (res, listener) {
  if (!res) {
    throw new TypeError('argument res is required')
  }

  if (typeof listener !== 'function') {
    throw new TypeError('argument listener must be a function')
  }

  res.writeHead = createWriteHead(res.writeHead, listener)
}


function createWriteHead (prevWriteHead, listener) {
  var fired = false

  return function writeHead (statusCode) {
    // ....
    var args = setWriteHeadHeaders.apply(this, arguments)

    if (!fired) {
      fired = true
      listener.call(this)
      // ....
    }

    return prevWriteHead.apply(this, args)
  }
}
```

至此 cookie-session 主干逻辑源码解读完毕，接下来看看更加底层的 Cookie 库实现原理。

## Cookie 实现原理
### Cookie.set
Cookie.set 主要做了两件事：
- Cookie 签名
- 生成 Cookie 字符串，并写到响应头

```js
var Keygrip = require('keygrip')

// *** cookie set
function Cookies(request, response, options) {
  // ....
  this.keys = new Keygrip(options)
  // ....
}

Cookies.prototype.set = function (name, value, opts) {
  var res = this.response
    // ....
    // 调用 Node 原生方法 res.getHeader 获取 Set-Cookie 字段
    , headers = res.getHeader("Set-Cookie") || []
    , cookie = new Cookie(name, value, opts)
    , signed = opts && opts.signed !== undefined ? opts.signed : !!this.keys

  if (typeof headers == "string")
    headers = [headers]

  pushCookie(headers, cookie)

  if (opts && signed) {
    // ...
    cookie.value = this.keys.sign(cookie.toString())
    cookie.name += ".sig"
    pushCookie(headers, cookie)
  }

  //
  var setHeader = res.set ? http.OutgoingMessage.prototype.setHeader : res.setHeader

  setHeader.call(res, 'Set-Cookie', headers)
  return this
};

function pushCookie(headers, cookie) {
  // ....
  headers.push(cookie.toHeader())
}

Cookie.prototype.toString = function () {
  return this.name + "=" + this.value
};

Cookie.prototype.toHeader = function () {
  var header = this.toString()

  if (this.maxAge) this.expires = new Date(Date.now() + this.maxAge);

  if (this.path) header += "; path=" + this.path
  if (this.expires) header += "; expires=" + this.expires.toUTCString()
  if (this.domain) header += "; domain=" + this.domain
  // if(this.xxx)  xxx += "; xxx=" + this.xxx 
  // .....

  return header
};
```

可以看到 `pushCookie(headers, cookie)` 将 Cookie 实例转换成字符串并拼接到 headers 变量。在生成 Cookie 串后，如果开发者要求签名，`Cookie.set` 会再生成一个以当前 Cookie 名称开头，以 sig 结尾的 Cookie，该 Cookie 的值是原始 Cookie 串签名后的字符串。  

```js
  pushCookie(headers, cookie)

  if (opts && signed) {
    // ...
    cookie.value = this.keys.sign(cookie.toString())
    cookie.name += ".sig"
    pushCookie(headers, cookie)
  }
```

现在来看看签名是怎么做的，也就是 [sign](https://github.com/crypto-utils/keygrip#keyssigndata) 方法的内部实现。`this.keys` 是在 `new Cookie()` 时绑定的 `Keygrip` 实例，我们看看 [Keygrip](https://github.com/crypto-utils/keygrip) 的源码就好。其实就是使用 SHA1 算法进行签名，然后以 Base64URL 的形式输出。

```js
var crypto = require("crypto")

function Keygrip(keys, algorithm, encoding) {
  if (!algorithm) algorithm = "sha1";
  if (!encoding) encoding = "base64";

  // ..
  function sign(data, key) {
    return crypto
      .createHmac(algorithm, key)
      .update(data).digest(encoding)
      // Base64 有三个字符+、/和=，在 URL 里面有特殊含义，所以要被替换掉：=被省略、+替换成-，/替换成_ 。这就是 Base64URL 算法。
      .replace(/\/|\+|=/g, function(x) {
        return ({ "/": "_", "+": "-", "=": "" })[x]
      })
  }

  this.sign = function(data) { 
   return sign(data, keys[0]) 
  }
}
```

### Cookie.get
Cookie.get 主要做了三件事：
1. 从请求头中读取开发者设置的 Cookie
1. 从请求头中读取签名后的 Cookie
1. 校验签名是否合法：对第一步获取 Cookie 进行签名然后与第二步中获取到的 Cookie 对比是否相等，相等即签名合法

```js
var compare = require('tsscmp')

// **** Cookie 源码 ****  
// get cookie
Cookies.prototype.get = function (name, opts) {
  var sigName = name + ".sig"
    , header, match, value, remote, data, index
    , signed = opts && opts.signed !== undefined ? opts.signed : !!this.keys


  // ....
  header = this.request.headers["cookie"]

  // 从 header 字符串中匹配出对应 cookie 名称的字符串
  match = header.match(getPattern(name))
  if (!match)
    return

  // 获取 cookie 的值
  value = match[1]
  if (!opts || !signed)
    return value

  // 递归调用 get 方法，获取签名后 cookie
  remote = this.get(sigName)
  if (!remote)
    return

  data = name + "=" + value

  // ...
  // 校验 cookie 签名是否合法
  index = this.keys.index(data, remote)

  if (index < 0) {
    this.set(sigName, null, { path: "/", signed: false })
  } else {
    index && this.set(sigName, this.keys.sign(data), { signed: false })
    return value
  }
};

// *** Keygrip 源码 ***
// 校验签名是否合法
this.index = function (data, digest) {
  for (var i = 0, l = keys.length; i < l; i++) {
    if (compare(digest, sign(data, keys[i]))) {
      return i
    }
  }

  return -1
}
```

看到这里有些同学可能会有疑问，为什么 [keygrip](https://github.com/crypto-utils/keygrip#keyssigndata) 的 `index` 方法不直接用 `===` 判断签名是否有效，而是用 [tsscmp](https://github.com/suryagh/tsscmp) 这个库判断。这样做其实是为了防止时序攻击，有兴趣的朋友可以阅读这篇文章——[如何通俗地解释时序攻击(timing attack)?](https://www.zhihu.com/question/20156213)了解。

## 总结
至此 cookie-session 相关源码解读完毕，看似简单的设置 Cookie、下发 Cookie 的第三方库，顺着源码深究进去其实会发现有很多值得学习的点，比如 JWT、防篡改签名、Base64、响应结束监听、如何获取头信息、如何设置头信息、时序攻击等等。

## 参考
- [jwt.io](https://jwt.io/)
- [JSON Web Token 入门教程](https://www.ruanyifeng.com/blog/2018/07/json_web_token-tutorial.html)
- [五个步骤轻松弄懂 JSON Web Token（JWT）](https://www.tomczhen.com/2017/05/25/5-easy-steps-to-understanding-json-web-tokens-jwt/)
- [如何通俗地解释时序攻击(timing attack)?](https://www.zhihu.com/question/20156213)
