---
title: 前端 CLI 的前世今生
date: 2022-03-20 22:18:12
categories: 技术
---

## [Yeoman](https://yeoman.io/)

Yeoman 是一个功能强大，且使用稍有点复杂的 CLI 库，早在 2014 年前发布了，一直流行至今。用 Yeoman 编写的模板有 [generator-node](https://github.com/yeoman/generator-node)、[generator-eslint](https://github.com/eslint/generator-eslint) 等等。

### 使用

以 [generator-eslint](https://github.com/eslint/generator-eslint) 为例，我们要使用这个模板生成项目只需要先全局安装 Yeoman 和 generator-eslint。

```bash
npm i -g yo
npm i -g generator-eslint
```

接着在终端运行 `yo eslint:plugin` 即可生成一个 eslint 插件项目。

### 编写 Generator

接下来讲下如何使用 Yeoman 编写项目模板，Yeoman 把生成代码的功能描述为 Generator。Generator 项目需要以 `generator-` 开头。Generator 无非是由三部分组成：

- 用户交互：提示用户进行功能选择
- 文件操作：文件内容变量编译、写文件等等
- 依赖操作：对 `package.json` 的依赖进行修改

Yeoman Generator 也不例外，下面主要讲下 Yeoman Generator 里个人觉得比较重要的功能：

- 提供 [Prompt API](https://yeoman.io/authoring/user-interactions.html) 进行用户交互
- [生命周期勾子](https://yeoman.io/authoring/running-context.html)：编写 Generator 时，开发者需要遵循 Yeoman 提供的勾子在不同的勾子实现相应的功能，比如在 `prompting` 勾子调用 `this.prompt()` 提示用户进行选择。

![Untitled](/images/cli-history/Untitled.png)

- 提供 [命令行操作 API](https://yeoman.github.io/generator/actions_spawn-command.html)：一般用于 npm 操作
- 提供 [git 操作 API](https://yeoman.github.io/generator/actions_user.html)
- 提供 [package.json 文件操作 API](https://yeoman.github.io/generator/actions_package-json.html)：用于修改 `package.json` 文件内容
- 提供 [常用文件操作 API](https://yeoman.io/authoring/file-system.html)：[文件内容变量编译、写文件等等](https://yeoman.github.io/generator/actions_fs.html)
- 提供 [compose](https://yeoman.io/authoring/composability.html) 对功能进行解耦：[generator-node](https://github.com/yeoman/generator-node) 是个很值得学习的库，可以看到它支持的选项有很多，把这个库读一遍基本能理解 Yeoman 大部分功能了。从 generator-node 目录可以看到每个选项由一个 generator，然后用 compose 进行连接，这样能很好对功能进行解耦，以后需要加选项则多加一个 generator 就可以，方便维护。

![generator-node 支持的选项](/images/cli-history/img.png)（generator-node 支持的选项）

![generator-node 目录](/images/cli-history/img_1.png)（generator-node 目录）

## [SAO](https://github.com/saojs/sao)
> SAO was made because yeoman, while powerful, is too complex. vue-cli, on the other hand, is more than a scaffolding tool and lacks some important features like unit testing. SAO combines the powerful core features of yeoman with the simplicity of vue-cli into a single application.

SAO 是与 Vue CLI2 同期的作品。正如上面 SAO 主页提及的那样，Yeoman 虽然强大，但还是有一点学习成本的。而 Vue CLI（这里指的是 Vue CLI2）虽然易用，但是缺少了一些像单元测试这样重要的功能。作者结合 Vue CLI 的易用性，以及 Yeoman 的核心功能整合到一个库，这就是 SAO。

对比 [SAO File](https://sao.vercel.app/saofile.html) 从这个 [Vue CLI2 的模板](https://github.com/vuejs-templates/webpack/blob/develop/meta.js)，如出一辙。SAO 核心功能如下

- prompt：用户交互
- actions：对文件进行增加、修改、移动、删除
- hooks：只有 prepare、completed 两个生命周期勾子，非常简单
- 模板编译

通过 SAO 与 Yeoman 的对比可以发现，SAO 是重流程的 CLI 工具，开发 Generator 过程需要考虑的东西都集成在 [SAO File](https://sao.vercel.app/saofile.html)。而 Yeoman 虽然看起来生命周期勾子比较多，但其实对流程管控没有 SAO 强，但是它的 API 比 SAO 要强大很多，基于这点用 Yeoman 来开发 Generator 会更加灵活，而 SAO 偏「傻瓜式」点，更加简单，有 Vue 的味道。用 SAO 编写的模板可以参考[这里](https://github.com/saojs/awesome-sao)。

## Vue CLI3

Vue CLI3 与 Vue CLI2 相比最大的变化是加入插件化机制。从 [Vue CLI2 Webpack 模板](https://github.com/vuejs-templates/webpack)可以看出，对于选项差异化的处理还是比较简单粗暴的，直接一个 `if` 语句解决，好歹 Yeoman 还有 Compose 这种东西对功能进行解耦。这种用 `if else` 来处理的方式很大地制约了功能的扩展，Vue CLI3 支持 TS 配置如果用这种方式，代码肯定非常恶心。

![Vue CLI2  官方 Webpack 模板](/images/cli-history/Untitled%201.png)（Vue CLI2 官方 Webpack 模板）

```jsx
/*
* webpack/template/build/webpack.base.conf.js
*/

// ....

{{#lint}}const createLintingRule = () => ({
  test: /\.(js|vue)$/,
  loader: 'eslint-loader',
  enforce: 'pre',
  include: [resolve('src'), resolve('test')],
  options: {
    formatter: require('eslint-friendly-formatter'),
    emitWarning: !config.dev.showEslintErrorsInOverlay
  }
}){{/lint}}

module.exports = {
  context: path.resolve(__dirname, '../'),
  entry: {
    app: './src/main.js'
  },
  output: {
    path: config.build.assetsRoot,
    filename: '[name].js',
    publicPath: process.env.NODE_ENV === 'production'
      ? config.build.assetsPublicPath
      : config.dev.assetsPublicPath
  },
  // ...
}
```

针对上面问题，Vue CLI3 使用插件化机制，Vue CLI3 由多个包组成，核心包 cli 只负责控制流程，cli-service 包提供基础模板，然后针对特定选项提供不同的插件输出不同的代码模板，比如 cli-plugin-router、cli-plugin-typescript、cli-plugin-babel 等等。同时，插件化还有一个好处就是可以给开发者提供一个入口完善 Vue 生态。

## Vue UI

还没用过 Vue UI 之前，我以为这只是个提供图形界面用于生成 Vue 项目的方式。用了一次后就被震住了，它不仅仅可以用来生成项目，我觉得这个工具最厉害的地方在于，它把项目我们平时最关心的信息都整合进来了。可以看看下面两个图感受一下，打包信息、包体积分析这些功能都集成了，这对于我们分析项目做一些优化非常有帮助。而且基于团队的情况我们可以在此基础上把更多的功能集成进去，让我们能更加全面地了解项目。

![Untitled](/images/cli-history/Untitled%202.png)

![Untitled](/images/cli-history/Untitled%203.png)

## [SAO2](https://github.com/saojs/sao/tree/releases/v2.0.0-beta.2)

Vue CLI3 的问题是只适用于 Vue 项目，如果我们想编写其他框架的模板就不适用了。SAO2 是一个还在开发中的项目，个人估计作者是准备参考 Vue CLI3 那套插件化机制对 SAO 进行重写，为 SAO 提供更好的扩展性。

## 参考

- [【前端工程化基础 - 初始化项目】现代 CLI 和 GUI 方案指南](https://mp.weixin.qq.com/s/o7kt8IWZ0u07a2z0O573Ew)
- [Vue CLI 3.0 UI控制台初体验](https://segmentfault.com/a/1190000015366009)
