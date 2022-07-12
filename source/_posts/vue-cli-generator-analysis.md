---
title: Vue CLI Generator 源码浅析
date: 2022-03-30 22:18:12
categories: 技术
---

![img_1.png](/images/vue-cli-generator-analysis/img_1.png)

最近公司开发 CLI 需求，找了 Vue CLI 的源码阅读（版本为 [4.5.15](https://github.com/vuejs/vue-cli/tree/v4.5.15)）。CLI 主要分成两部分，执行 `vue create [projectname]` 生成项目，执行 `vue run server` 启动打包服务，本文主要讲述生成项目原理。  

## 流程概要

主要代码在 `/packages/@vue/cli` 这个包 ，主要分成三个模块，大流程如下：

- Creator：这个类用于控制整个大流程，从发起用户询问到代码生成、npm 安装、git 初始化等等
- PromptModule：询问用户模块，主要负责设置问题，以及插件挂载（将需要加载的插件名称保存到一个数组）
- Generator：加载插件、执行插件获取写入的内容，写文件

## 询问模块

```jsx
/*
* packages/@vue/cli/package.json
*/
{
  "name": "@vue/cli",
  "bin": {
    "vue": "bin/vue.js"
  }
}

/*
* packages/@vue/cli/bin.js
*/
program
  .command('create <app-name>')
  // ....
  .action((name, options) => {
    // ...
    require('../lib/create')(name, options)
  })

/*
* packages/@vue/cli/create.js
*/
async function create (projectName, options) {
// ....
const creator = new Creator(name, targetDir, getPromptModules())
await creator.create(options)
}
```

从项目 `package.json` 开始分析可以知道，执行 `vue create [projectname]` 命令之后，先会 `new Creator`，接着执行 `createor.create`。`Creator` 构造方法主要是遍历 `lib/promptModules` 目录，收集各个模块需要询问的问题。

```jsx
/*
* packages/@vue/cli/lib/Creator.js
*/
module.exports = class Creator extends EventEmitter {
  constructor(name, context, promptModules) {
    super()
    // ...
    this.injectedPrompts = []
    this.promptCompleteCbs = []

    this.run = this.run.bind(this)

    // 遍历 lib/promptModules 目录，收集各个模块需要询问的问题
    const promptAPI = new PromptModuleAPI(this)
    promptModules.forEach(m => m(promptAPI))
  }
}
```

![promptModules 目录](/images/vue-cli-generator-analysis/Untitled.png)（promptModules 目录）

我们以 TS 模块为例，看看下 `packages/@vue/cli/lib/promptModules/typescript.js` 长什么样子。TS 模块向问题链加入了两个问题，第一个是否使用 TS，如果用户选择了使用 TS，就再询问是否使用`tsClassComponent`。再注册一个回调，当询问完成将对应的选项保存到 `plugins` 对象。

```jsx
/*
* packages/@vue/cli/lib/promptModules/typescript.js
*/
module.exports = cli => {
  cli.injectFeature({
    name: 'TypeScript',
    value: 'ts',
    short: 'TS',
    description: 'Add support for the TypeScript language',
    link: 'https://github.com/vuejs/vue-cli/tree/dev/packages/%40vue/cli-plugin-typescript',
    plugins: ['typescript']
  })

  cli.injectPrompt({
    name: 'tsClassComponent',
    when: answers => answers.features.includes('ts'),
    type: 'confirm',
    message: 'Use class-style component syntax?',
    description: 'Use the @Component decorator on classes.',
    link: 'https://vuejs.org/v2/guide/typescript.html#Class-Style-Vue-Components',
    default: answers => answers.vueVersion !== '3'
  })

  // ....

  cli.onPromptComplete((answers, options) => {
    if (answers.features.includes('ts')) {
      const tsOptions = {
        classComponent: answers.tsClassComponent
      }
      // ....
      options.plugins['@vue/cli-plugin-typescript'] = tsOptions
    }
  })
}
```

## 加载插件

`Creator` 实例构造完成后，接下来调用 `creator.create`。`promptAndResolvePreset`  被调用，终端开始使用 `promptModules` 收集的问题询问用户，最终得到 `preset`，`preset.plugins` 包含接下来生成代码需要用到的插件。

看看 `preset.plugins['@vue/cli-service']` 这个语句，内置的 `@vue/cli-service` 插件用于生成基础代码模板，后面会详细讲到。插件收集完成后就调用 `resolvePlugins` 加载插件，接着遍历 `preset.plugins` 将对应依赖名称添加到将要生成的 `package.json`，供 cli  service 使用（至于 cli  service 怎么用，下一篇文章讲述）。

```jsx
/*
* packages/@vue/cli/lib/Creator.js
*/
module.exports = class Creator extends EventEmitter {
  // ....
  async create() {
    // ...
    const preset = await this.promptAndResolvePreset()
    // preset 就是长这样子的
    // preset = {
    //   plugins: {
    //     '@vue/cli-plugin-typescript': {
    //       tsClassComponent: true
    //       // ....
    //     }
    //   },
    //   // ...
    // }

    // ...
    preset.plugins['@vue/cli-service'] = Object.assign({
      projectName: name
    }, preset)
    // ...

    // 加载插件
    const plugins = await this.resolvePlugins(preset.plugins, pkg)

    // generate package.json with plugin dependencies
    const pkg = {
      name,
      version: '0.1.0',
      private: true,
      devDependencies: {},
      ...resolvePkg(context)
    }
    
    // 遍历 presets 将对应依赖名称添加到将要生成的 package.json
    const deps = Object.keys(preset.plugins)
    deps.forEach(dep => {
      // ...
      let { version } = preset.plugins[dep]
      // ...
      pkg.devDependencies[dep] = version
    })
    
    // 内部对插件进行排序
    const generator = new Generator(context, {
      pkg,
      plugins,
      // ...
    })
    
    // 执行插件
    await generator.generate({
      extractConfigFiles: preset.useConfigFiles
    })
  }
  // ....
}
```

详细看看 `resolvePlugins` 方法，此方法遍历 `preset.plugins` 对象，使用 `loadModule`（内部用 `require` 实现）加载插件目录下的 Generator 模块。

```jsx
/*
* packages/@vue/cli/lib/Creator.js
*/

// { id: options } => [{ id, apply, options }]
async resolvePlugins (rawPlugins, pkg) {
  rawPlugins = sortObject(rawPlugins, ['@vue/cli-service'], true)
  const plugins = []
  for (const id of Object.keys(rawPlugins)) {
    const apply = loadModule(`${id}/generator`, this.context) || (() => {})
    let options = rawPlugins[id] || {}
    // ...
    plugins.push({ id, apply, options })
  }
  return plugins
}
```

我们看看下面两个插件， `generator/index.js` 用于控制生成代码流程，而 `template`  目录就是接下来生成代码的模板。

![cli-plugin-typescript](/images/vue-cli-generator-analysis/Untitled%201.png)（cli-plugin-typescript）

![cli-service](/images/vue-cli-generator-analysis/Untitled%202.png)（cli-service）

## 执行插件生成代码

回到 `create` 流程，插件加载完成后，进行  `new Generator`。

```jsx
/*
* packages/@vue/cli/lib/Creator.js
*/
const plugins = await this.resolvePlugins(preset.plugins, pkg)

const generator = new Generator(context, {
  pkg,
  plugins,
  // ...
})

// 执行插件
await generator.generate({
  extractConfigFiles: preset.useConfigFiles
})
```

接着 `generator.generate` 执行 `initPlugins` 遍历插件，执行 `plugin.apply(new GeneratorAPI()))` 进行代码生成，也就是执行上文提到的插件目录下的 `generator/index.js`。

```jsx
/*
* packages/@vue/cli/lib/Generator.js
*/

module.exports = class Generator {
  // ...
  async generate({
                   extractConfigFiles = false,
                   checkExisting = false
                 } = {}) {
    await this.initPlugins()
    const initialFiles = Object.assign({}, this.files)
    // ...
    await this.resolveFiles()
    // ...
    this.files['package.json'] = JSON.stringify(this.pkg, null, 2) + '\\n'
    await writeFileTree(this.context, this.files, initialFiles, this.filesModifyRecord)
  }

  async initPlugins() {
    const { rootOptions, invoking } = this
    // ...
    // apply generators from plugins
    for (const plugin of this.plugins) {
      const { id, apply, options } = plugin
      const api = new GeneratorAPI(id, this, options, rootOptions)
      await apply(api, options, rootOptions, invoking)
      // ...
    }
  }
}
```

我们来看看 `cli-plugin-typescript` 的 generator，它做事情就是将 `package.json` 加上 `typescript` 依赖。

```jsx
/*
* cli-plugin-typescript/generator/index.js
*/

const pluginDevDeps = require('../package.json').devDependencies

module.exports = (
  api,
  { skipLibCheck = true }
) => {

  // ....
  api.extendPackage({
    devDependencies: {
      typescript: pluginDevDeps.typescript
    }
  })
  // ....
  api.render('./template', {
    skipLibCheck,
  })

  require('./convert')(api, { convertJsToTs })
}

// 让 ts plugin 在 router plugin 之后执行
module.exports.after = '@vue/cli-plugin-router'
```

接着调用 `render` 调用 `_injectFileMiddleware` 注册回调保存到 `fileMiddlewares`，收集需要编译的文件，回调的时机后面会提及。

```jsx
/*
* packages/@vue/cli/lib/GeneratorAPI.js
*/

module.exports = class GeneratorAPI {

  _injectFileMiddleware (middleware) {
    this.generator.fileMiddlewares.push(middleware)
  }

  render (source, additionalData = {}, ejsOptions = {}) {
    const baseDir = extractCallDir()
    if (isString(source)) {
      source = path.resolve(baseDir, source)

      // 收集需要编译的文件目录
      this._injectFileMiddleware(async (files) => {
        const data = this._resolveData(additionalData)
        const globby = require('globby')
        const _files = await globby(['**/*'], { cwd: source, dot: true })

        for (const rawPath of _files) {// 遍历目录下所有文件执行 ejs 进行编译
          const targetPath = /*....*/
          const sourcePath = path.resolve(source, rawPath)
          // renderFile 使用 ejs 对模板编译
          const content = renderFile(sourcePath, data, ejsOptions)
          if (Buffer.isBuffer(content) || /[^\\s]/.test(content)) {
            files[targetPath] = content
          }
        }

      })
    }
    // .....
  }
}
```

最后调用 `convert.js`，该方法注册 `postProcessFiles` 回调，`postProcessFiles` 回调是修改文件的最后一次机会，这里是将所有 `.js` 文件名改成 `.ts`。

```jsx
/*
* packages/@vue/cli-plugin-typescript/generator/convert.js
*/

module.exports = (api, { convertJsToTs = true } = {}) => {
  const jsRE = /\\.js$/
  let excludeRE = /^tests\\/e2e\\/|(\\.config|rc)\\.js$/

  // ...

  api.postProcessFiles((files) => {
    if (convertJsToTs) {
      for (const file in files) {
        if (jsRE.test(file) && !excludeRE.test(file)) {
          const tsFile = file.replace(jsRE, '.ts')
          if (!files[tsFile]) {
            const content = files[file]
            files[tsFile] = content
          }
          delete files[file]
        }
      }
    }

    // ...
  })
}
```

## 编译、写文件

我们回到主流程，上文`initPlugins` 执行完毕后， `resolveFiles` 方法执行 `render` 收集的 `fileMiddlewares`。`fileMiddlewares` 读取 template 目录下的文件，调用 `ejs` 编译它们，然后保存到 `this.files`。最后`resolveFiles` 调用 `postProcessFilesCbs` 执行上文 `covert.js` 注册的回调。

```jsx
/*
* packages/@vue/cli/lib/Generator.js
*/

async resolveFiles () {
  const files = this.files
  for (const middleware of this.fileMiddlewares) {
    await middleware(files, ejs.render)
  }

  // ...
  for (const postProcess of this.postProcessFilesCbs) {
    await postProcess(files)
  }
}
```

最后 `generate` 调用 `writeFileTree` 将 files 数组保存的文件内容写入到硬盘，到此代码生成流程完毕。

```jsx
/*
* packages/@vue/cli/lib/Generator.js
*/

module.exports = class Generator {
  // ...
  async generate({
                   extractConfigFiles = false,
                   checkExisting = false
                 } = {}) {
    await this.initPlugins()
    // ...
    await this.resolveFiles()
    // ...
    this.files['package.json'] = JSON.stringify(this.pkg, null, 2) + '\\n'
    await writeFileTree(this.context, this.files, initialFiles, this.filesModifyRecord)
  }
}
```

## 插件执行顺序

这里我们再讲点小的知识点， `cli-plugin-typescript/generator/index.js` 最后一句 `module.exports.after = '@vue/cli-plugin-router'`，表示 ts 插件应该放在 router 插件后执行。原因是这样的，我们看看下面这个继承 `@vue/cli-plugin-router/generator/template/src/views/HomeView.vue` 的模板（关于模板语法可以参考[官方文档](https://cli.vuejs.org/zh/dev-guide/plugin-dev.html#%E5%88%9B%E5%BB%BA%E6%96%B0%E7%9A%84%E6%A8%A1%E6%9D%BF)），如果 ts 插件先执行，router 插件后执行，那么最终结果是 router 插件的 `HomeView.vue` 模板，而不是 ts 插件的  `HomeView.vue` 模板，显然这不是我们想要的。

```
/* 
* packages/@vue/cli-plugin-typescript/generator/template-vue3/src/views/HomeView.vue
*/

---
extend: '@vue/cli-plugin-router/generator/template/src/views/HomeView.vue'
when: "rootOptions.plugins && rootOptions.plugins['@vue/cli-plugin-router']"
replace:
  - !!js/regexp /Welcome to Your Vue\\.js App/
  - !!js/regexp /<script>[^]*?<\\/script>/
---

<%# REPLACE %>
Welcome to Your Vue.js + TypeScript App
<%# END_REPLACE %>

<%# REPLACE %>
<script lang="ts">
<%_ if (!options.classComponent) { _%>
import { defineComponent } from 'vue';
import HelloWorld from '@/components/HelloWorld.vue'; // @ is an alias to /src

export default defineComponent({
  name: 'HomeView',
  components: {
    HelloWorld,
  },
});
<%_ } else { _%>
import { Options, Vue } from 'vue-class-component';
import HelloWorld from '@/components/HelloWorld.vue'; // @ is an alias to /src

@Options({
  components: {
    HelloWorld,
  },
})
export default class HomeView extends Vue {}
<%_ } _%>
</script>
<%# END_REPLACE %>
```

那么，插件是怎样排序的呢？其实是在 `Generator` 构造方法中调用 [sortPlugins](https://github.com/vuejs/vue-cli/blob/4be4bb39ad2c1998f06c62e7f30a205c42b86649/packages/%40vue/cli-shared-utils/lib/pluginOrder.js) 方法实现，这里就不展示讲了，感兴趣的同学可以自己阅读源码。

## 总结

最后我们再来对 Vue CLI Generator 简单做个总结

- 插件执行：收集（依靠各 Prompt 模块 Inject）→ 加载插件 → 处理插件数组（比如插件排序）→ 执行
- 代码生成：收集（依靠各插件 Render）→ 处理文件数组（比如从 pkg 提取 lint 配置、ejs 编译文件 → 后置处理文件勾子 → 写文件

可以看到，两个流程都是 `收集 → 中间处理 → 最后执行` 这样的模式，而`收集`主要依靠各个插件来完成，主流程通过中间处理对收集得到的数组进行一些需求处理，最后真正执行插件。通过这种插件化的方式很好对代码进行解耦，利于后续维护扩展。
