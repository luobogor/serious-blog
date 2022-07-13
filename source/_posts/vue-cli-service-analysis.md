---
title: Vue CLI Service 源码浅析
date: 2022-04-09 22:18:12
categories: 技术
---

![img.png](/images/vue-cli-service-analysis/img.png)

继上文 [Vue CLI Generator 源码浅析](https://yejinzhan.gitee.io/2022/03/30/vue-cli-generator-analysis/)，本文结合 [cli-plugin-typescript](https://github.com/vuejs/vue-cli/tree/v4.5.15/packages/%40vue/cli-plugin-typescript) 讲述执行 `npm run serve` ，Vue CLI Service （版本为 [4.5.15](https://github.com/vuejs/vue-cli/tree/v4.5.15)）内部是如何进行 Webpack 配置。

## 加载插件
从 `/packages/@vue/cli-service/package.json` 的 `bin` 字段开始我们顺藤摸瓜找到 Service 这个核心类。

```js
/*
* packages/@vue/cli-service/package.json
*/
{
  // ....
  "name": "@vue/cli-service",
  "bin": {
    "vue-cli-service": "bin/vue-cli-service.js"
  }
}

/*
* packages/@vue/cli-service/bin/vue-cli-service.js
*/
const Service = require('../lib/Service')
const service = new Service(process.env.VUE_CLI_CONTEXT || process.cwd())
// command 为 server、build、....
service.run(command, args, rawArgv).catch(err => {
  error(err)
  process.exit(1)
})
// ....
```

如果你使用 Vue CLI 生成项目选择了使用 TS，那么生成的项目的 `package.json` 会带有 `@vue/cli-plugin-typescript` 依赖。

```json5
{
  "name": "ts-demo",
  "scripts": {
    "serve": "vue-cli-service serve",
    // ...
  },
  "devDependencies": {
    "@vue/cli-plugin-typescript": "~4.5.0",
    // ...
  },
  // ...
}
```

`new Service` 时执行 `resolvePlugins` 将内置的插件、以及从用户项目的 `package.json` 中找到以 `@vue/cli-plugin-` 开头的的插件加载到数组。回到 `bin/vue-cli-service.js` 方法，接着执行 `service.run`，当 `init` 被调用的执行这些插件。

```js
/*
* cli-service/lib/service.js
*/
module.exports = class Service {
  constructor(context, { plugins, pkg, inlineOptions, useBuiltIn } = {}) {
    // ...
    this.plugins = this.resolvePlugins(plugins, useBuiltIn)
    // ...
  }

  resolvePlugins(inlinePlugins, useBuiltIn) {
    const idToPlugin = id => ({
      id: id.replace(/^.\\//, 'built-in:'),
      apply: require(id) // 引入插件
    })

    let plugins

    const builtInPlugins = [
      './commands/serve',
      './config/base', //  Webpack 基础配置
      // ....
    ].map(idToPlugin)

    // ...
    const projectPlugins = Object.keys(this.pkg.devDependencies || {})
      .concat(Object.keys(this.pkg.dependencies || {}))
      .filter((id) => {
        return /^(@vue\\/|vue-|@[\\w-]+(\\.)?[\\w-]+\\/vue-)cli-plugin-/.test(id)
      })
      .map(id => {
        // ....
        return idToPlugin(id)
      })
    plugins = builtInPlugins.concat(projectPlugins)
    // ...

    return plugins
  }

  init(mode = process.env.VUE_CLI_MODE) {
    // ...
    this.plugins.forEach(({ id, apply }) => {
      // ...
      // 执行插件
      apply(new PluginAPI(id, this), this.projectOptions)
    })

    // ...
  }

  async run (name, args = {}, rawArgv = []) {
    // resolve mode
    // prioritize inline --mode
    // fallback to resolved default modes from plugins or development if --watch is defined
    const mode = args.mode || (name === 'build' && args.watch ? 'development' : this.modes[name])

    // load env variables, load user config, apply plugins
    await this.init(mode)

    // name 为 dev
    let command = this.commands[name]
    const { fn } = command
    // 执行 command dev
    return fn(args, rawArgv)
  }
}
```

## 命令注册
`packages/@vue/cli-service/lib/commands/serve.js` 插件则注册 `serve` 这个命令，`registerCommand` 将 callback 保存到 `commands` 对象。所以上面代码 `run` 最后一行 `fn(args, rawArgv)` 执行就是 callback，也就是说所有的插件执行完毕后，这个 callback 才会被执行。这时 `resolveWebpackConfig` 将 Webpack Chain 转换成 Webpack 配置对象，拿到 Webpack 配置对象后就可以调用 `webpack` 方法进行打包了，至此整个 serve 流程完毕。

```js
/*
* packages/@vue/cli-service/lib/commands/serve.js
*/

/** @type {import('@vue/cli-service').ServicePlugin} */
module.exports = (api, options) => {
  // 注册命令
  api.registerCommand('serve', {
    description: 'start development server',
    usage: 'vue-cli-service serve [options] [entry]',
    options: {
      '--open': `open browser on server start`,
      // ...
    }
  }, async function serve (args) {
    // ...
    const webpack = require('webpack')
    const webpackConfig = api.resolveWebpackConfig()
    webpack(webpackConfig)
    // ...
  })
}
```

## 插件执行

`./config/base` 插件利用 Webpack Chain API 加载基础配置，接着 TS 插件通过 Webpack Chain 先是修改入口文件为 `main.ts`，然后再添加  TS 相关 Webpack 配置。

```js
/*
* cli-plugin-typescript/index.js
*/
module.exports = (api) => {
  // ....
  api.chainWebpack(config => {
    /*
    * 修改入口文件为 main.ts
    */
    config.entry('app')
      .clear()
      .add('./src/main.ts')

    /*
     * 使用 Webppack Chain 添加 ts 配置相应的 loader 和 plugin
     */
    const tsRule = config.module.rule('ts').test(/\\.ts$/)
    const tsxRule = config.module.rule('tsx').test(/\\.tsx$/)

    // add a loader to both *.ts & vue<lang="ts">
    const addLoader = ({ name, loader, options }) => {
      tsRule.use(name).loader(loader).options(options)
      tsxRule.use(name).loader(loader).options(options)
    }

    // ....
    addLoader({
      name: 'babel-loader',
      loader: require.resolve('babel-loader')
    })

    addLoader({
      name: 'ts-loader',
      loader: require.resolve('ts-loader'),
      options: {
        transpileOnly: true,
        appendTsSuffixTo: [ '\\\\.vue$' ],
      }
    })

    // make sure to append TSX suffix
    tsxRule.use('ts-loader').loader(require.resolve('ts-loader')).tap(options => {
      options = Object.assign({}, options)
      delete options.appendTsSuffixTo
      options.appendTsxSuffixTo = [ '\\\\.vue$' ]
      return options
    })

    config
      .plugin('fork-ts-checker')
      .use(require('fork-ts-checker-webpack-plugin'), [ {
        typescript: {
          extensions: {
            vue: {
              enabled: true,
              compiler: isVue3 ? require.resolve('vue/compiler-sfc') : require.resolve('vue-template-compiler')
            }
          },
          diagnosticOptions: {
            semantic: true,
            // <https://github.com/TypeStrong/ts-loader#happypackmode>
            syntactic: false
          }
        }
      }])
  })
}
```
