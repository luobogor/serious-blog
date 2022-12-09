![](https://gitee.com/yejinzhan/images/raw/master/20200530155854.jpeg)

随着公司项目越做越复杂，因前期团队对 Vue 使用经验不足，导致留下比较多坑。再这样下去项目会变成越来越难以维护，于是我对主管说：“主管，我想重构”，便有了这次的重构经历。经过对项目分析，主要存在以下问题：

- 全局样式满天飞
- 组件越来越多，管理不方便
- 核心页面 1300 多行代码，阅读性非常差

> 本项目是一个金融类项目，采用可视化的资产架构描述方式，并根据资产架构生成税务报告。使用 Vue 全家桶进行业务开发，并在 Element UI 基础上进行定制化，可视化建模使用 mxGraph

## 减少全局样式
项目出现全局样式满天飞的情况，有以下原因

- 组件内样式想要覆写子组件样式，去除了 scoped 关键字
- 为了样式在不同组件间复用，将样式提到了全局

组件销毁后，Vue是不会删除对应样式标签的，所以组件内样式不写 scoped 存在污染全局样式的风险。

为了解决第一个问题，这次重构的做法是，坚决所有组件都使用 scoped。需要覆写子组件时使用深度作用选择器解决。这样仅不会污染全局样式，还对子组件覆写样式一目了然。

对于弹窗这类确实要作用到全局的样式，我们统一写在命名为 global.scss 的文件，并使用 BEM 规范命名。

对于在组件间复用的样式，分模块地放到 modules 文件夹下，组件内使用时再用 @import 导入。

来看看重构后的 style 文件夹长这个样子

![图片](https://ws4.sinaimg.cn/large/006tKfTcgy1g0mf6gtjcij30ow0dgmyh.jpg)

全局样式样式只剩下 nomalize.css、一些自定义的 reset、element-ui 的默认样式、上文提到的 global，还有就是图标。

## 分类管理组件

未重构前，全局基础组件放置在 components/common 文件夹，业务组件与其他未归类的组件全放在 components 文件下，看起来非常混乱。

经重构后，将组件分为五类: business、common、function、slot，还有一种就是为某个页面特定提供的，下面会提到。

![图片](https://ws3.sinaimg.cn/large/006tKfTcgy1g0ogaes2p6j30a903r74a.jpg)

business 为业务组件跟业务有耦合，可在页面间复用，但不适用于其他项目。而 slot、function、common 这几类是可脱离当前项目使用的。 slot、function 与 common 一样，不同的是 common 使用频率非常高是全局注册的。而 slot、function 是局部注册使用的。slot 的特别之处在于，这类组件只提供一个样式外壳，无太多交互，能很好地被其他组件利用。

像下图所示其他 Panel 组件都可以复用 slot目录下的 Panel 组件。

![图片](https://ws4.sinaimg.cn/large/006tKfTcgy1g0mglnh6msj30mh0l6n03.jpg)

这次重构经我总结后得出应该在这两种情况下创建组件
- 可复用的，如上面提到 components 目录下的组件
- 不可复用的，纯粹为了减少某个页面代码，使 template 结构更清晰： 例如仅仅是传入 props 做数据展示，又或者该组件直接与页面进行交互，该组件无嵌套其他组件

像下面 NodeDetail 页面分离出来的 components 就是上面提到的不可复用组件。

![图片](https://ws2.sinaimg.cn/large/006tKfTcgy1g0ogdvbcp7j30740a5gly.jpg)

## 拆分大文件
我们系统核心页面就是画图页。该页面共三个组件，左侧的元素面板、右侧的节点面板、右侧的线条面板。交互与大多可视化建模软件相同，用户将左侧元素拖拽到画布，从节点拖出线条连接到另一个节点，当用户在画布上选择节点时右侧面板显示节点相关操作，选择线条亦然(同一时刻只能选择一个节点或者一条线条)。与 draw.io 有点相似，但我们做的不是绘图应用。

### 精简 methods
经过我对该页面代码进行浏览后发现，该页面之所有这么多代码是因为，在编写方法过程中我们会习惯性地将大的方法拆分成小的方法，结果这些小的方法都堆在 methods，导致 template 事件处理函数非常不显眼。所以这次重构目标就是删除 methods 对象中除页面初始化方法外的所有非事件处理方法。也就是说 methods 对象中的每个方法都应该对应一个 template 事件处理。

那么问题来了拆分出来的小方法不放在 methods ，该放到什么地方？根据我对画布页面代码分析，发现这个页面其实只对有三个东西进行操作：架构、节点、线条。于是按照这个思路独立出有三个 js 文件，将 this 当作参数传入到各自的模块，用来操作 vm 对象。同时将 js 从 vue 文件中独立出来。重构之后该页面目录长成了这个样子

![图片](https://ws3.sinaimg.cn/large/006tKfTcgy1g0ogeyqpjsj308509fq3c.jpg)

js/index.js 是页面的 vm 对象，重构后代码由原来的1000多行精简成了300多行，提高了可维护性。

### 使用面向接口编程
这个页面js还存在一个问题，大量的 if/else 判断。这里先扯一点 mxGraph 的东西，在 mxGraph 中节点与线条都统称为 Cell，当节点或线条被删除时 mxGraph 会派发一个 CELL_REMOVE 事件，但是这个 Cell 是节点还是线条还是要程序员自己去判断的，这也导致了我们系统出现了很多下面这样的判断语句

```js
functoin syncRemove(cell) {
	// 判断是节点还是线条
	const cellIsVertex = cell.vertex;
	if(cellIsVertex){
		// 执行删除节点
	} else {
		// 执行删除线条
	}
}
```

经过我思考许久后得出两个方案

1. 对 mxGraph 的每个 Cell 事件进行细分成节点与线条事件。比如接收到 CELL_REMOVE 事件后，判断是节点还是线条然后触发自定义事件 VERTEX_REMOVE 或者 EDGE_REMOVE，之后我们只需监听 VERTEX_XXX 与 EDGE_XXX 即。这样做虽然让事件变得更加具体清晰，但是在细分过程中同样不可避免写出多个 if/else 判断是节点还是线条，于是弃用了这个方案。
2. 使用面向接口编程。上文提到我将该页面的交互分成有三个模块:节点、线条、架构，既然节点、线条有相同的操作，那么他们应该实现共同的接口。于是乎将代码改造成这样子
	
	```js
	// vertexOp.js
	const vertexOp = {
	  // *********
	  // Interface
	  // *********
	  handleActive(vertex) {
	  	// 节点被点出时该执行的操作
	  },
	  async syncAdd(vertex) {},
	  syncRemove(vertex) {},
	  // Others ....
	}
	  
	  
	// edgeOp.js
	const edgeOp = {
	  // *********
	  // Interface
	  // *********
	  handleActive(edge) {},
	  async syncAdd(edge) {},
	  syncRemove(edge) {},
	  // Others ....
	}  
	```
	
	当用户选择不同 Cell 的时候，只需要在选择事件处理器中做一次判断即可。
	
	```js
	// index.js 
	let opContex = null;
	let activeCell = null;
	
	const listenSelectionChange = ()=> {
		activeCell = graph.getSelectionCell();
		const cellIsVertex = activeCell.vertex;
		if(cellIsVertex){
			opContex = vertexOp;
		} else {
			opContex = edgeOp;
		}
	}
	
	const handleRemoveEvent = ()=> {
		contexOp.syncRemove(activeCell);
	}
	```
	
### 使用请求拦截将零碎的方法调用集中起来
这个页面再一个问题是，出现这多零散的方法调用。比如像下面的需求

需求：当用户做了任何改变架构外观的操作都将当前架构截图同步到服务端用作该架构的封面展示。

重构前做法：
  - 添加节点，在相应处理方法最后加一句截图发送请求
  - 修改节点信息，在相应处理方法最后加一句截图发送请求
  - 移动节点，在相应处理方法最后加一句截图发送请求
  - 添加线条，在相应处理方法最后加一句截图发送请求
  - 修改线条信息，在相应处理方法最后加一句截图发送请求
  - ........ 在相应处理方法最后加一句截图发送请求

重构后做法：
拦截全局请求，判断到是相关操作的请求则截图发请求

具体做法是对请求进行命名，然后在每个请求发送完成时使用全局 eventBus 发送一个请求完成事件。事件处理器只需要根据请求名称判断是否需要截图发送请求。代码思路如下

```js
// api层
// api/nodes.js
import http from '@/config/axios/index';

export default {
  all: data => http('/nodes', data, 'GET'),
  one: id => http(`/nodes/${id}`, 'GET'),
  save: data => http('/nodes', data, 'POST', 'nodes-save'),
  del: id => http(`/nodes/${id}`, 'DELETE', 'nodes-del'),
  // .....
};


// 封装 axios
// config/axios/index.js
export default function (...args) {
  const url = args[0];
  let data;
  let method;
  let name;
  // 参数重载
  if (args.length === 2) {
    method = args[1];
  } else if (args.length === 3) {
    if (_.isString(args[1]) && _.isString(args[2])) {
      method = args[1];
      name = args[2];
    } else {
      data = args[1];
      method = args[2];
    }
  } else if (args.length === 4) {
    data = args[1];
    method = args[2];
    name = args[3];
  } else {
    throw new Error('http support max 4 args');
  }

  if (_.isNil(name)) {
    // 没有命名的请求，默认命名为当前时间戳
    name = String(Date.now());
  } else {
	// 有命名的请求，为了保证请求的唯一性，加上时间戳后缀
    name = `${name}__${Date.now()}`;
  }
  return $axios({ url, data, method }, name);
}

async function $axios(initialOptions, requestName) {
  const options = getOptions(initialOptions);
  initialOptions.requestName = requestName;
  requestManager.addReq({
    name: requestName,
    config: initialOptions,
  });
	
  try {
    const response = await axios(options);
    requestManager.popReq({
      name: requestName,
      response,
    });
    return response.data;
  } catch (error) {
    // 保证即便请求出错也要使该请求弹出队列
    requestManager.popReq({
      name: requestName,
      error,
    });
    return {};
  }
}

// 发送请求相关事件
// requestManager.js
import Vue from 'vue';

const $bus = Vue.prototype.$bus;

class RequestManager {
  constructor() {
    this._updateRequests = [];
  }

  addReq(req) {
    if (req.config.method.toLowerCase() === 'get') {
      return;
    }
    this._updateRequests.push(req);
    $bus.$emit('before-modify-req-send', req);
  }

  popReq({ name, response }) {
    if (response && response.config.method.toLowerCase() === 'get') {
      return;
    }
    const idx = this._updateRequests.findIndex(item => item.name === name);
    if (idx >= 0) {
      this._updateRequests.splice(idx, 1);
      $bus.$emit('modify-req-finished', name, response);
      if (this._updateRequests.length === 0) {
        $bus.$emit('modify-req-empty');
      }
    }
  }
}

// RequestManager是一个全局的单例对象
export default new RequestManager();
```

最终只需要对请求进行拦截，就可以大量减少零散的方法调用

```js
// xxx.vue
this.$bus.$on('modify-req-finished', (name, response) => {
  const reqs = ['c-transitions-updateRatio',
    'c-transitions-save',
    'c-transitions-del',
    /*..........*/];
  const reqName = name.split('__')[0];
  if (reqs.includes(reqName)) {
    // 截图，发送请求
  }
});
```

除此之外请求拦截还适用于这个场景: 当用户做了操作，实时提示用户操作保存中，保存完成后提示用户操作已保存。
使用请求拦截非常轻松完成这个功能，只需要监听发送请求事件、请求队列清空事件做相应提示即可。

## 总结
这次重构一人完成，用时一星期，做了如下工作

- 使用划分模块的方式减少全局样式
- 归类组件
- 使用如下方式拆分大文件
	- 精简 methods
	- 拆分模块
	- 使用面向接口编程
	- 使用请求拦截

感悟比较深的是，网上虽然很多文章教你怎样用 Vue 做好项目，但实际情况还是要从项目自身出发，自己一定要对项目进行思考，我相信没有适合所有项目的 "Vue最佳实践"。只要不断对项目进行思考、改进，才能找到最适合自身项目的架构方式。

<section class="custom-bottom">
  欢迎关注 Luobo FE，更多精彩内容持续出炉🔥
</section>

![](/images/common/qrcode.jpg)
