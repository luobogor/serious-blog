代码仓库地址见文末「参考」，主要对 Vuex 源码进行浓缩，DIY 一个小型 Vuex，功能如下：

1. 通过 `$store.commit` 改变 `$store.state`
2. 实现 strict model 严格模式，即不能直接修改 state，只能通过 mutation 修改 state

代码约 70 行左右比较好理解，下面讲解一下两个重点。

## install
`Vue.use(Vuex)`实际上调用的是 Vuex 的 `install` 方法，该方法在每个组件的 `beforeCreate` 钩子中为当前组件注入 `$store`，使所有组件的 `$store` 属性都指向同一个对象，也就是创建 Vue 实例时传入的 `store` 对象。

## 监听 store
为什么当 state 对象发生变化时视图会被更新？原因是 store 内部创建了一个 Vue 对象对 state 进行监听(见源码 `resetStoreVM` 方法)。而且上面也提到，使用 Vuex 后，所有组件的 `$store` 都引用的都是同一个 store。当使用了 state 的视图渲染时就会触发 state 的 getter 收集渲染 Watcher 依赖。当 state 变化时，触发相应属性的 setter，渲染 Watcher 更新视图。

## 参考
- Demo 仓库 https://github.com/luobogor/diy-vuex

<section class="custom-bottom">
  欢迎关注 Luobo FE，更多精彩内容持续出炉🔥
</section>

![](/images/common/qrcode.jpg)
