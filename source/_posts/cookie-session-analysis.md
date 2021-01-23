---
title: cookie-session 源码解读
date: 2021-01-25 08:55:12
categories: 技术
---

## 关于 JWT
查看 jwt.md

点题 cookie-session 是利用 jwt 实现，而 express-session 是在服务端存储 session

## cookie-session 实现原理
### 整体流程
开篇先整体讲下接收到请求和请求结束时发生了什么事情，有助于大家理解接下来要讲的代码细节。可以结合这个 Demo 一起理解这篇文章。

cookie-session 调用 Cookie.get 从请求头中读取 Cookie，以及读取该 Cookie 的签名，并校验签名是否合法。如果是合法则将该 Cookie 字符串返回给 cookie-session，cookie-session 再将该串反序列化成一个 Session 对象。拿到 Session 对象后开发者可以对 session 进行一些操作。

请求结束时 cookie-session 将当前的 session 实例进行序列化，再调用 Cookie.set 设置两个 Cookie，一个是序列化后的 session 实例，一个是该 cookie 的签名，也就是 Demo 响应里以 .sig 结尾的 Cookie。

```
HTTP/1.1 200 OK
X-Powered-By: Express
Set-Cookie: my-session=eyJ0b2tlbkEiOiJmb28iLCJ0b2tlbkIiOiJiYXIifQ==; path=/; expires=Fri, 12 Feb 2021 09:18:49 GMT; httponly
Set-Cookie: my-session.sig=8IJIgYrEoLp0MvJma_LtT2YjDKY; path=/; expires=Fri, 12 Feb 2021 09:18:49 GMT; httponly
Date: Sat, 23 Jan 2021 09:18:49 GMT
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

先来看 `cookieSession` 这个方法做了什么事情，首先是保证在开启签名选项 `signed` 后保证开发者传入的 options 的 `keys` 或 `secret` 其中一个必须，因为后续签名要使用。然后就是返回一个中间件。

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
    set: setSession// 赋值 req.session 时触发
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

`_cookieSession` 的主干逻辑并不复杂，50 行左右。从代码可以看到，req 上绑定了一个 session 实例供开发者使用，整体可以分两个流程，一个是请求进来时读取 cookie，也就是 `getSession` 的逻辑。另一个设置 cookie，其中包括开发者设置 cookie 时调用的 `setSession` 逻辑，以及请求结时触发的 `onHeaders` 逻辑。而这些逻辑的底层都是依赖于第三库 `Cookies` 的 `get` 与 `set` 方法实现，这两个方法的内部实现讲完整体流程后会讲述。

### 读取 Cookie

先讲一下从请求头中读取 cookie 的逻辑，也就是 `getSession`。当开发者读取 session 信息，比如以下代码

```js
const tokenA = req.session.tokenA

// 或者（这种写法先是触发 getter，再是触发 setter）
req.session.tokenA = 'foo'
```

就会触发 `req.session` 的 getter 方法，出就是调用 `getSession`，`getSession` 调用 `tryGetSession`

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

最终调用 `Cookies.get` 从请求头中读取 cookie，当请求头中没有 cookie 的时候，也就是用户第一次访问网站的时间, `getSession` 会调用 `Session.create` 创建 `Session` 实例。现在我们先来看看 `Session` 的类设计，当请求头存在 cookie 走 `Session.deserialize` 逻辑后面讲。 

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

从上面代码可以看到，最终构造出来的 `Session` 实例是这样子的。

```js
/**
Cookie.get -> getReqCookie(name, value)、getReqCookie(`${name}`.sig, sign(value))、validateSign -> 逆 Base64 解码 -> JSON.parse -> sess
**/

const sess = {// Session
  // .... 开发者可以添加多个 key
  _ctx: { // SessionContext
    _new: true, // 是否为新的 SessionContext
    _value: undefined, // 经过 base64 编码后的值
  }
}

const sess = {// Session
  tokenA: 'foo',
  tokenB: 'bar',
  // .... 开发者可以添加多个 key
  _ctx: { // SessionContext
    _new: false, // 
    _value: 'eyJ0b2tlbkEiOiJmb28iLCJ0b2tlbkIiOiJiYXIifQ==', // 经过 Base64 编码后的值，也就是 base64Encode(JSON.stringify({ tokenA: 'foo', tokenB: 'bar' }))
  }
}
```

`_ctx` 是个 `unenumerable` 属性，所以 _ctx 是不会被 `JSON.stringify 转换`。`_new` 表示是否为新的 `SessionContext` 实例。

对比 `Session.create` 与 `Session.deserialize`，可以发现

上文提到过如果是请求头中存在 cookie，会通过 `Session.deserialize` 创建 `Session` 实例，这时 `_new` 为 `false`。而 _value 则是 `Cookie.get` 获取的值。 _value 逆 Base64 解码后可以得到一个 `Session` 实例。

### 设置 Cookie
`onHeaders` 的回调会在请求将要结束时被调用，`Cookie.set` 将经过 JSON.stringify 及 Base64 编码后的字符串设置到响应头中，同时加上签名。

```js
/**
JSON.stringify(sess) -> Base64 encode -> Cookie.set -> resSetCookie(name, value)、resSetCookie(`${name}`.sig, sign(value))
**/

Session.serialize = function serialize (sess) {
  return encode(sess)
}

function encode (body) {
  var str = JSON.stringify(body)
  return Buffer.from(str).toString('base64')
}
```

顺便看下 onHeader 的源码，逻辑并不复杂。请求结束时 express 内部调用 Node 原生的 res.end 方法，而 `res.end` 内部会调用 res.writeHeader，onHeaders 对 res.writeHead 进行了简单的重写，使得开发者可以监听 `res.writeHead`。

```
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
  // TODO 为什么会用到 fired 变量 
  var fired = false

  return function writeHead (statusCode) {
    // ....
    // TODO 为什么？
    // var args = setWriteHeadHeaders.apply(this, arguments)
    if (!fired) {
      fired = true
      listener.call(this)
      // ....
    }

    return prevWriteHead.apply(this, args)
  }
}
```

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

可以看到 `pushCookie(headers, cookie)` 将 cookie 实例转换成字符串并拼接到 headers 变量。在生成 Cookie 串后，如果开发者要求签名，`Cookie.set` 会再生成一个以当前 cookie 名称开头，以 sig 结尾的 cookie，该 cookie 的值是原始 cookie 串签名后的字符串。  

```js
  pushCookie(headers, cookie)

  if (opts && signed) {
    // ...
    cookie.value = this.keys.sign(cookie.toString())
    cookie.name += ".sig"
    pushCookie(headers, cookie)
  }
```

现在来签名是怎么做的，也就是 `sign` 方法的内部实现。this.keys 是在 `new Cookie()` 时绑定的 `Keygrip` 实例，我们看看 `Keygrip` 的源码就好。

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

其实就是使用 SHA1 算法进行加密，然后以 Base64URL 的形式输出。

### Cookie.get
Cookie.set 主要做了三件事：
1. 从请求头中读取开发设置的 Cookie
1. 从请求头中读取签名后的 Cookie
1. 校验签名是否合法

```js
// **** get cookie
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

  // 获取 cookie 字符串
  value = match[1]
  if (!opts || !signed)
    return value

  // 递归调用 get 方法，获取 cookie 签名
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
    // 没看懂，为什么要在 index > 0 的情况下设置 signed 为 false 的 cookie，debugger 正常情况下 index 为 0，不会走这个逻辑
    index && this.set(sigName, this.keys.sign(data), { signed: false })
    return value
  }
};
```


```js
this.index = function (data, digest) {
  for (var i = 0, l = keys.length; i < l; i++) {
    if (compare(digest, sign(data, keys[i]))) {
      return i
    }
  }

  return -1
}
```
