---
title: Tina.js 源码分析
date: 2020-03-08 21:54:28
categories: 技术
---

![Cover](https://gitee.com/yejinzhan/images/raw/master/20200530155744.png)

目前公司团队小程序框架使用的是 [Tina.js](https://tina.js.org/#/)，这篇文章将讲解这个框架的源码。阅读文章时可以对照着这个[小工程](https://github.com/jinzhanye/my-tina/tree/master/test/sayhi/libraries)阅读源码，这个小工程主要是对 tina 加了更多的注释及示例。

## 是什么

Tina.js 是一款轻巧的渐进式微信小程序框架，不仅能充分利用原生小程序的能力，还易于调试。
这个框架主要是对 Component、Page 两个全局方法进行了封装，本文主要介绍 [Tina.js 1.0.0]() 的 `Paeg.define` 内部做了些什么。`Component.define` 与 `Paeg.define`相似，理解 `Paeg.define` 之后自然也就理解 `Component.define`。为什么是讲解 1.0.0 ？因为第一个版本的代码相对于最新版本主干内容更更清晰更容易上手。

![类图](https://gitee.com/yejinzhan/images/raw/master/20200530175804.png)

## 概览

为了避免混淆 tina 和原生的一些概念，这里先说明一下一些词的含义

- wx-Page - 原生 Page 对象
- tina-Page - `tina/class/page` 这个类
- wxPageOptions - 构建原生 Page 实例的 options
- tinaPageOptions - 构建原生 tina-Page 实例的 options

开局先来预览一下 `Page.define` 的流程

```js
// tina/class/page.js
class Page extends Basic {
  static mixins = []
  static define(tinaPageOptions = {}) {
    // 选项合并
    tinaPageOptions = this.mix(/*....*/)
    
    // 构建原生 options 对象
    let wxPageOptions = {/*.....*/}
    
    // 在原生 onLoad 时做拦截，关联 wx-Page 对象和 tina-Page 对象
    wxPageOptions = prependHooks(wxPageOptions, {
      onLoad() {
        // this 是小程序 wx-Page 实例
        // instance 是这个 tina-Page 实例
        let instance = new Page({ tinaPageOptions })
        // 建立关联
        this.__tina_instance__ = instance
        instance.$source = this
      }
    })
    
    // 构造 wx-Page 对象
    new globals.Page({
       // ...
       ...wxPageOptions,
     })
  }
  constructor({ tinaPageOptions = {} }) {
    super()
    //.......
  }
  get data() {
   return this.$source.data
  }
}
```

下面针对每个小流程做讲解

## mix
tina 的 mixin 是靠 js 对对象做合并实现的，并没有使用原生的 `behaviors`

```js
tinaPageOptions = this.mix(PAGE_INITIAL_OPTIONS, [...BUILTIN_MIXINS, ...this.mixins, ...(tinaPageOptions.mixins || []), tinaPageOptions])
```

Tina.js 1.0.0 只支持一种合并策略，跟 Vue 的默认合并策略一样

- 对于 methods 就是后面的覆盖前面的
- 对于生命周期勾子和特殊勾子（onPullDownRefresh 等），就是变成一个数组，还是后面的先执行
- 也就是 tinaPageOptions.mixins > Page.mixins（全局 mixin） > BUILTIN_MIXINS

合并后可以得到这样一个对象

```
{
  // 页面
  beforeLoad: [$log.beforeLoad, options.beforeLoad],
  onLoad: [$initial.onLoad, options.onLoad],
  onHide: [],
  onPageScroll: [],
  onPullDownRefresh: [],
  onReachBottom: [],
  onReady: [],
  onShareAppMessage: [],
  onShow: [],
  onUnload: [],
  // 组件
  attached: Function,
  compute: Function,
  created: $log.created,
  // 页面、组件共用
  data: tinaPageOptions.data,
  methods: tinaPageOptions.methods,
  mixins: [],
}
```

合并后是创建 wx-Page 对象，至于创建 wx-Page 对象过程做了什么，为了方便理解整个流程，在这里暂时先跳过讲解，放在后面 `改变执行上下文` 小节再讲解。

## 关联 wx-Page、tina-Page
为了绑定 wx-Page 对象，tina 在 wx-onLoad 中追加了一些操作。
prependHooks 是作用是在 `wxPageOptions[hookName]` 执行时追加 `handlers[hookName]` 操作，并保证 `wxPageOptions[hookName]`、`handlers[hookName]` 的执行上下文是原生运行时的 `this`

```js
// tina/class/page
wxPageOptions = prependHooks(wxPageOptions, {
  onLoad() {
    // this 是 wxPageOptions
    // instance 是 tina-Page 实例
    let instance = new Page({ tinaPageOptions })
    // 建立关联
    this.__tina_instance__ = instance
    instance.$source = this
  }
})


// tina/utils/helpers.js

/**
 * 在 wx-page 生命周期勾子前追加勾子
 * @param {Object} context
 * @param {Array} handlers
 * @return {Object}
 */
export const prependHooks = (context, handlers) =>
 addHooks(context, handlers, true)

function addHooks (context, handlers, isPrepend = false) {
  let result = {}
  for (let name in handlers) {
    // 改写 hook 方法
    result[name] = function handler (...args) {
      // 小程序运行时, this 是 wxPageOptions
      if (isPrepend) {
        // 执行 tina 追加的 onLoad
        handlers[name].apply(this, args)
      }
      if (typeof context[name] === 'function') {
        // 执行真正的 onLoad
        context[name].apply(this, args)
      }
      // ...
    }
  }
  return {
    ...context,
    ...result,
  }
}
```

## 构建 tina-Page
接下来再来看看 `new Page` 做了什么

```js
  constructor({ tinaPageOptions = {} }) {
    super()
    // 创建 wx-page options
    let members = {
      // compute 是 tina 添加的方法
      compute: tinaPageOptions.compute || function () {
        return {}
      },
      ...tinaPageOptions.methods,
      // 用于代理所有生命周期（包括 tina 追加的 beforeLoad）
      ...mapObject(pick(tinaPageOptions, PAGE_HOOKS), (handlers) => {
        return function (...args) {
          // 因为做过 mixin 处理，一个生命周期会有多个处理方法
          return handlers.reduce((memory, handler) => {
            const result = handler.apply(this, args.concat(memory))
            return result
          }, void 0)
        }
      }),
      // 以 beforeLoad、onLoad 为例，以上 mapObject 后追加的生命周期处理方法实际执行时是这样的
      // beforeLoad(...args) {
      //  return [onLoad1、onLoad2、.....].reduce((memory, handler) => {
      //    return handler.apply(this, args.concat(memory))
      //  }, void 0)
      //},
      // onLoad(...args) {
      //   return [onShow1、onShow2、.....].reduce((memory, handler) => {
      //     return handler.apply(this, args.concat(memory))
      //   }, void 0)
      // },
    }

    // tina-page 代理所有属性
    for (let name in members) {
      this[name] = members[name]
    }

    return this
  }
```

首先是将 `tinaPageOptions` 变成跟 `wxPageOptions` 一样的结构，因为 wxPageOptions 的 `methods` 和 `hooks` 都是在 options 的第一层的，所以需要将将 methods 和 hooks 铺平。
又因为 hooks 经过 mixins 处理已经变成了数组，所以需要遍历执行，每个 hooks 的第二个参数都是之前累积的结果。然后通过简单的属性拷贝将所有方法拷贝到 tina-Page 实例。

## 改变执行上下文
上面提到构建一个属性跟 wx-Page 一模一样的 tina-Page 对象，那么为什么要这样呢？一个框架的作用是什么？我认为是在原生能力之上建立一个能够提高开发效率的抽象层。现在 tina 就是这个抽象层，
举个例子来说就是我们希望 `methods.foo` 被原生调用时，tina 能在 `methods.foo` 里做更多的事情。所以 tina 需要与原生关联使得所有本来由原生处理的东西转交到 tina 这个抽象层处理。
那 tina 是如何处理的呢。我们先来看看创建 `wxPageOptions` 的源码 

```js
// tina/class/page.js
let wxPageOptions = {
  ...wxOptionsGenerator.methods(tinaPageOptions.methods),
  ...wxOptionsGenerator.lifecycles(
    inUseOptionsHooks,
    (name) => ADDON_BEFORE_HOOKS[name]
  ),
 }


// tina/class/page.js
/**
 * wxPageOptions.methods 中的改变执行上下文为 tina.Page 对象
 * @param {Object} object
 * @return {Object}
 */
export function methods(object) {
  return mapObject(object || {}, (method, name) => function handler(...args) {
    let context = this.__tina_instance__
    return context[name].apply(context, args)
  })
}
```

答案就在 `wxOptionsGenerator.methods`。上面说过在 `onLoad` 的时候会绑定 `__tina_instance__` 到 wx-Page，同时 wx-Page 与 tina-Page 的属性都是一模一样的，所以调用会被转发到 tina 对应的方法。这就相当于 tina 在 wx 之上做了一个抽象层。所有的被动调用都会被 tina 处理。而且因为上下文是 `__tina_instance__` 的缘故，
所有主动调用都先经过 tina 再到 wx。结合下面两个小节会有更好的理解。

![调用拦截](https://gitee.com/yejinzhan/images/raw/master/20200530175702.png)

## 追加生命周期勾子
上面创建 `wxPageOptions` 时有这么一句 `wxOptionsGenerator.lifecycles` 代码，这是 tina 用于在 `onLoad` 之前加多一个 `beforeLoad` 生命周期勾子，这个功能是怎么做的呢，我们来看看源码

```js
// tina/utils/wx-options-generator

/**
 * options.methods 中的改变执行上下文为 tina.Page 对象
 * @param {Array} hooks
 * @param {Function} getBeforeHookName
 * @return {Object}
 */
export function lifecycles(hooks, getBeforeHookName) {
  return fromPairs(hooks.map((origin) => {
    let before = getBeforeHookName(origin) // 例如 'beforeLoad'
    return [
      origin, // 例如 'load'
      function wxHook() {
        let context = this.__tina_instance__
        // 调用 tina-page 的方法，例如 beforeLoad
        if (before && context[before]) {
          context[before].apply(context, arguments)
        }
        if (context[origin]) {
          return context[origin].apply(context, arguments)
        }
      }
    ]
  }))
}
```

其实就是改写 `onLoad` ，在调用 `tina-Page.onLoad` 前先调用 `tina-Page.beforeLoad`。可能有的人会有疑问，为什么要加个 `beforeLoad` 勾子，这跟直接 `onLoad` 里不都一样的么。
举个例子，很多时候我们在 `onLoad` 拿到 `query` 之后是不是都要手动去 `decode`，利用全局 `mixins` 和 `beforeLoad`，可以一次性把这个事情做了。

```js
Page.mixins = [{
  beforeLoad(query) {
    // 对 query 进行 decode
    // 对 this.$options 进行 decode
  }
}]
```

还有一点需要注意的是，tina 源码中了多次对 `onLoad` 拦截，执行顺序如下 

```
prependHooks.addHooks.handler -> wx-Page.onLoad，关联 wx-Page、tinaPage -> 回到 prependHooks.addHooks.handler -> lifecycles.wxHook -> tina-Page.beforeLoad -> tina-Page.onLoad
```

如下图所示


![启动流程](https://gitee.com/yejinzhan/images/raw/master/20200530175707.png)

## compute 实现原理
因为运行时的上下文都被 tina 改为 tina-Page，所以开发者调用的 `this.setData`， 实际上的 tina-Page 的 `setData` 方法，又因为 tina-Page 继承自 Basic，也就调用 Basic 的 setData 方法。下面看看 `setData` 的源码

```js
setData(newer, callback = () => {}) {
  let next = { ...this.data, ...newer }
  if (typeof this.compute === 'function') {
    next = {
      ...next,
      ...this.compute(next),
    }
  }
  next = diff(next, this.data)
  this.constructor.log('setData', next)
  if (isEmpty(next)) {
    return callback()
  }
  this.$source.setData(next, callback)
}
```

从源码可以看到就是每次 `setData` 的时候调用一下 `compute` 更新数据，这是 `compute`  的原理，很容易理解吧。

前面 `mix` 小节提到，tina 会合并一些内置选项，可以看到在 `onLoad` 时会调用`this.setData`，为了初始化 compute 属性。

```js
// mixins/index.js

function initial() {
  // 为了初始化 compute 属性
  this.setData()
  this.$log('Initial Mixin', 'Ready')
}

export const $initial = {
  // ...
  onLoad: initial,// 页面加载完成勾子
}
```

## 小结 
到此基本上把 `Page.define` 主干流程讲完，如有疑问欢迎留言

## 参考
- [《tina 文档》](https://tina.js.org/#/?id=tinajs)
