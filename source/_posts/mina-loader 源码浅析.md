---
title: mina-loader 源码浅析
date: 2020-03-15 21:54:28
categories: 技术
---

![](https://gitee.com/yejinzhan/images/raw/master/20200530155628.jpeg)

团队最近需要对小程序进行工程化升级，在网上看了[《小程序工程化实践》](https://juejin.im/post/5d00aa5e5188255a57151c8a)一文收获满满，刚好文章中提到的 [mina-webpack](https://github.com/tinajs/mina-webpack) 也是我们团队正在使用的工具。mina-webpack 是 [tinaJS](https://tina.js.org/#/?id=main) 配套的工程化工具。（有关 tinaJS源码在我的另一篇[文章](https://segmentfault.com/a/1190000021949561)有讲述）`mina-webpack` 包括好几个包，其中 `mina-runtime-webpack-plugin`、`mina-entry-webpack-plugin`、`mina-loader` 最为重要。《小程序工程化实践》已经讲解了 `mina-runtime-webpack-plugin`、`mina-entry-webpack-plugin` 的原理，本文主要讲解 `mina-loader` 原理。可结合 [demo 项目](https://github.com/jinzhanye/mina-loader-demo)一起阅读。

## webpack 信息分析
mina-loader 的作用是将 `.mina` 文件分离成 `.json`、`.wxml`、`.js`、`wxss` 四种类型文件。

```
// app.mina
<config>
{
  "tabBar": {}
}
</config>

<template>
  <page>Hello World</page>
</template>

<script>
App({
  onLaunch () {
    console.log('Hello onLauch')
  }
})
</script>

<style>
page {
  background: #fff;
}
</style>
```

对于 mina-loader 内部做了什么我们不从源码入手，
而是从 webpack 输出的信息进行的推导。进入 demo 项目的 example 目录，执行 `npm run dev`，可以看到如下信息

```
     Asset       Size  Chunks             Chunk Names
./app.json   18 bytes          [emitted]  
./app.wxml   24 bytes          [emitted]  
./app.wxss   28 bytes          [emitted]  
    app.js  314 bytes       0  [emitted]  app.js
 common.js    5.76 kB       1  [emitted]  common.js


[0] ./app.mina 95 bytes {0} [built]
[1] ../node_modules/@tinajs/mina-loader/lib/loaders/parser.js!./app.mina 390 bytes [built] 
[2] ../node_modules/@tinajs/mina-loader/lib/loaders/selector.js?type=script!./app.mina 66 bytes {0} [built]
[3] ../node_modules/@tinajs/mina-loader/node_modules/file-loader/dist/cjs.js?name=./[name].json!../node_modules/@tinajs/mina-loader/lib/loaders/mina-json-file.js?{"publicPath":"/"}!../node_modules/@tinajs/mina-loader/lib/loaders/selector.js?type=config!./app.mina 56 bytes [built]
[4] ../node_modules/@tinajs/mina-loader/node_modules/file-loader/dist/cjs.js?name=./[name].wxml!../node_modules/wxml-loader/lib?{"publicPath":"/"}!../node_modules/@tinajs/mina-loader/lib/loaders/selector.js?type=template!./app.mina 56 bytes [built]
[5] ../node_modules/@tinajs/mina-loader/node_modules/file-loader/dist/cjs.js?name=./[name].wxss!../node_modules/extract-loader/lib/extractLoader.js?{"publicPath":"/"}!../node_modules/css-loader!../node_modules/@tinajs/mina-loader/lib/loaders/selector.js?type=style!./app.mina 56 bytes [built]
```

可以看到输出了 6 个 `module`，webpack loader 是用 `!` 号作为分隔的，我们可以对上面最后 3 个 module 的信息做一下格式化

```
[3]
file-loader/dist/cjs.js?name=./[name].json!
mina-loader/lib/loaders/mina-json-file.js?{"publicPath":"/"}!
selector.js?type=config!
app.mina

[4]
file-loader/dist/cjs.js?name=./[name].wxml!
wxml-loader/lib?{"publicPath":"/"}!
selector.js?type=template!
app.mina

[5]
file-loader/dist/cjs.js?name=./[name].wxss!
extractLoader.js?{"publicPath":"/"}!
css-loader!
selector.js?type=style!
app.mina
```

webpack loader 是从右到左对于上面信息来说也就是下到上执行的。对于上面的 module 我们可以找到一些规律。对于每个 module，webpack 先是读取 `app.mina` 文件然后从下往上依次执行 loader 处理 `app.mina`。从上面三个 module 可以看出

- 第一个处理的  loader 都是 `selector-loader`
- 最后一个 loader 都是 `file-loader`，也就是最后肯定有文件输出，输出的是 `[name].json`、`[name].wxml`、`[name].wxss` 这几个文件。
- 再看看 `selecor-loader` 有个 `type`
参数，`type=style` 输出的是 `[name].wxss` 文件、`type=template` 输出的是 `[name].wxml` 文件、`type=style` 输出的是 `[name].wxss` 文件，由此可以推断出 `selector-loader` 的作用是按照 `type` 参数
对 `app.mina` 提取相关类型内容。
- 还有就是在 `selector-loader` 与 `file-loader` 之间的 loader，我们暂时称他们为中间  loader，不同类型的内容由特定的中间 loader 进行处理。

到此我们大概了解 `mina-loader` 的工作流程，就是分别按类型提取 `app.mina` 的内容，然后用特定的 loader 处理特定的内容，最后使用 `file-loader` 输出文件。

## 源码分析
`mina-loader `执行流程如下，跟上面说的流程差不多

![mina-loader流程.png](https://tva1.sinaimg.cn/large/00831rSTgy1gcuorm5hz3j30o60wewhp.jpg)

```
// process on 导出图片 parts 那部分有些问题，实际内容如下
parts = {
  "style": {
    "type": "style",
    "content": /*...*/,
  },
  "config": {
    "type": "config",
    "content": /*...*/,
  },
  "script": {
    "type": "script",
    "content": /*...*/,
  },
  "template": {
    "type": "template",
    "content": /*...*/,
  }
}
```

配合流程图看源码的话理解起来不困难

```js
// mina-loader/lib/loaders/mina

// 不同类型文件对应的中间 loader
const LOADERS = {
  template: ({ publicPath }) => `${resolve('wxml-loader')}?${JSON.stringify({ publicPath })}`,
  style: ({ publicPath }) => `${resolve('extract-loader')}?${JSON.stringify({ publicPath })}!${resolve('css-loader')}`,
  script: () => '',
  config: ({ publicPath }) => `${minaJSONFileLoaderPath}?${JSON.stringify({ publicPath })}`,
}

const EXTNAMES = {
  template: 'wxml',
  style: 'wxss',
  script: 'js',
  config: 'json',
}

const TYPES_FOR_FILE_LOADER = ['template', 'style', 'config']
const TYPES_FOR_OUTPUT = ['script']

module.exports = function () {
  // .....
  
  const done = this.async()
  const options = /*....*/

  // 获取剩余请求资源的路径，也就是 xx.mina 的路径
  // 例如 /Users/jinzhanye/Desktop/dev/github/mini/mina-webpack/example/src/app.mina
  const url = loaderUtils.getRemainingRequest(this)

  // 前置 !! 表示只执行行内 loader，其他 loader 都不执行
  // 拼接上 parserLoader 的路径
  const parsedUrl = `!!${parserLoaderPath}!${url}`

  const loadModule = helpers.loadModule.bind(this)

  // 获取对应类型的中间 loader
  const getLoaderOf = (type, options) => {
    let loader = LOADERS[type](options) || ''
    // .....
    return loader
  }

  loadModule(parsedUrl)
    .then((source) => {
      let parts = this.exec(source, parsedUrl)
      // parts 为以下对象
      // {
      //   config: {
      //     content: '.....'
      //   }
      //   wxml: {
      //     content: '.....'
      //   }
      //
      // }

      // compute output
      // 拼接 selector loader 路径
      // require("!!../node_modules/@tinajs/mina-loader/lib/loaders/selector.js?type=script!./app.mina")
      let output = parts.script && parts.script.content ?
        TYPES_FOR_OUTPUT.map((type) => `require(${loaderUtils.stringifyRequest(this, `!!${getLoaderOf(type, options)}${selectorLoaderPath}?type=script!${url}`)})`).join(';') :
        ''

      return Promise
        // emit files
        .all(TYPES_FOR_FILE_LOADER.map((type) => {
          if (!parts[type] || !parts[type].content) {
            return Promise.resolve()
          }
          // dirname 为 '.'
          let dirname = compose(ensurePosix, helpers.toSafeOutputPath, path.dirname)(path.relative(this.options.context, url))
          // 拼接 wxml、json、wxss 请求路径
          let request = `!!${resolve('file-loader')}?name=${dirname}/[name].${EXTNAMES[type]}!${getLoaderOf(type, options)}${selectorLoaderPath}?type=${type}!${url}`
          return loadModule(request)
        }))
        .then(() => done(null, output))
    })
    .catch(done)
}
```

前文一直没提到 loadModule 是哪里来的，其实 [loadModule](https://webpack.docschina.org/api/loaders/#this-loadmodule) 是 webpack loader 暴露给开发者使用的一个 api，用于在执行 loader 时也能去加载一个模块。然后再看看 selector-loader

## selector-loader

前文提到 `selector-loader` 是用来提取某一类型的文件内容

```js
module.exports = function (rawSource) {
  this.cacheable()
  const cb = this.async()
  const { type } = loaderUtils.getOptions(this) || {}
  // url = '!!parser.js!app.mina'
  const url = `!!${parserLoaderPath}!${loaderUtils.getRemainingRequest(this)}`
  this.loadModule(url, (err, source) => {
    if (err) {
      return cb(err)
    }
    const parts = this.exec(source, url)
    cb(null, parts[type].content)
  })
}
```

操作跟 `mina-loader` 很像，利用 `parser-loader` 将 `.mina` 文件转换成如下对象

```
parts = {
  "style": {
    "type": "style",
    "content": /*...*/,
  },
  "config": {
    "type": "config",
    "content": /*...*/,
  },
  "script": {
    "type": "script",
    "content": /*...*/,
  },
  "template": {
    "type": "template",
    "content": /*...*/,
  }
}

```

然后根据 `type` 返回对应的内容即可。但是这里有一个问题，我们看看下面代码

```
// mina-loader/lib/loaders/mina.js

// ...
const parsedUrl = `!!${parserLoaderPath}!${url}`
// ...
loadModule(parsedUrl)


// mina-loader/lib/loaders/parser.js
const url = `!!${parserLoaderPath}!${loaderUtils.getRemainingRequest(this)}`
this.loadModule(url,/*....*/)
```

可以看到 `loaderModule(parseredUrl)` 也就是 `loadModule('!!parser.js!app.mina')` 这个模块被重复加载了多次，这样的话会不会带来性能的损耗呢？答案是不会的，每次 `loadModule` 后 webpack 会将加载完的 module 以请求路径为 key 保存在 `Compilation` 对象。参考源码如下

```
// webpack/lib/Compilation.js
addModule(module, cacheGroup) {
	const identifier = module.identifier();
	// identifier 是 request 路径，在这个案例就是 'parser.js!app.mina'
	if(this._modules[identifier]) {
		return false;
	}
	// 缓存模块
	this._modules[identifier] = module;
	if(this.cache) {
	   this.cache[cacheName] = module;
	}
	this.modules.push(module);
	return true;
}
```

## 感谢
- [mina-webpack](https://github.com/tinajs/mina-webpack)
- [小程序工程化实践](https://juejin.im/post/5d00aa5e5188255a57151c8a)
