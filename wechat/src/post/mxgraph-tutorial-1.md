![Cover](https://gitee.com/yejinzhan/images/raw/master/20200530160357.png)

在上一篇文章 《记一次绘图框架技术选型: jsPlumb VS mxGraph》提到了我为什么要去学习 mxGraph。在入门时我遇到了以下几个问题

- 官方文档偏向理论，没能较好地结合代码进行讲解
- 虽然官方给出的例子很多，但没有说明阅读顺序，对刚入门的我不知道应该从哪开始阅读
- 通过搜索引擎搜索 「mxGraph教程」 没能得到太大帮助

通过自己对着官方文档死磕了一段时间并在公司项目中进行实践后，慢慢开始掌握这个框架的使用。下面我就根据我的学习经验写一篇比较适合入门的文章。

官方 https://jgraph.github.io/mxgraph 列了比较多文档，其中下面这几份是比较有用的。

- mxGraph Tutorial https://jgraph.github.io/mxgraph/docs/tutorial.html，这份文档主要讲述整个框架的组成
- mxGraph User Manual – JavaScript Client https://jgraph.github.io/mxgraph/docs/manual.html，这份文档对一些重要的概念进行讲解，以及介绍一些重要的 API 
- 在线实例 https://jgraph.github.io/mxgraph/javascript/index.html，这些实例的源码都在这里 https://github.com/jgraph/mxgraph/tree/master/javascript/examples 有
- API 文档 https://jgraph.github.io/mxgraph/docs/js-api/files/index-txt.html，这是最重要的一份文档，在接下来的教程我不会对接口作详细讲述，你可以在这里对相关接口作深入了解

在看完我的文章后希望系统地学习 mxGraph 还是要去阅读这些文档的，现在可以暂时不看。因为刚开始就堆这么多理论性的东西，对入门没有好处。

这篇教程分为两部分，第一部分结合我写的一些例子 https://github.com/jinzhanye/mxgraph-demos 讲解基础知识。第二部分则利用第一部分讲解的知识开发一个小项目 pokemon-diagram https://github.com/jinzhanye/pokemon-diagram。本教程会使用到 ES6 语法，而第二部分的项目是用 Vue 写的。阅读本教程需要你掌握这两项预备知识。

## 引入
### 使用 script 引入
我们来分析一下官方的 HelloWorld https://github.com/jgraph/mxgraph/blob/master/javascript/examples/helloworld.html 实例是怎样通过 script 标签引入 mxGraph 的

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Hello World</title>
</head>

<body>
<div id="graphContainer"></div>
</body>

<script>
mxBasePath = '../src';
</script>

<script src="../src/js/mxClient.js"></script>
<script>
	// ......
</script>
</html>
```

首先要声名一个全局变量 `mxBasePath` 指向一个路径，然后引入 mxGraph。

![2](https://gitee.com/yejinzhan/images/raw/master/20200530152148.jpeg)

`mxBasePath` 指向的路径作为 mxGraph 的静态资源路径。上图是 HelloWorld 项目的 `mxBasePah`，这些资源除了 js 目录 ，其他目录下的资源都是 mxGraph 运行过程中所需要的，所以要在引入 mxGraph 前先设置 `mxBasePath`。 

![3](https://gitee.com/yejinzhan/images/raw/master/20200530152155.jpeg)

再来看看 javascript 目录下有两个 `mxClient.js` 版本。 一个在 `javascript/src/js/mxClient.js` ，另一个在 `javascript/mxClient.js`，后者是前者打包后的版本，所以两者是可以替换使用的。如果你的项目是使用 script 标签引入 mxGraph，可以参考这个库 https://github.com/jinzhanye/mxgraph-demos/blob/master/src/01.helloworld.html 。

### 模块化引入
模块化引入可以参考 pokemon-diagram https://github.com/jinzhanye/pokemon-diagram 的这个文件 static/mxgraph/index.js https://github.com/jinzhanye/pokemon-diagram/blob/master/src/graph/index.js

```js
/*** 引入 mxgraph ***/
// src/graph/index.js
import mx from 'mxgraph';

const mxgraph = mx({
  mxBasePath: '/static/mxgraph',
});

//fix BUG https://github.com/jgraph/mxgraph/issues/49
window['mxGraph'] = mxgraph.mxGraph;
window['mxGraphModel'] = mxgraph.mxGraphModel;
window['mxEditor'] = mxgraph.mxEditor;
window['mxGeometry'] = mxgraph.mxGeometry;
window['mxDefaultKeyHandler'] = mxgraph.mxDefaultKeyHandler;
window['mxDefaultPopupMenu'] = mxgraph.mxDefaultPopupMenu;
window['mxStylesheet'] = mxgraph.mxStylesheet;
window['mxDefaultToolbar'] = mxgraph.mxDefaultToolbar;

export default mxgraph;


/*** 在其他模块中使用 ***/
// src/graph/Graph.js
import mxgraph from './index';

const {
  mxGraph,
  mxVertexHandler,
  mxConstants,
  mxCellState,
  /*......*/
} = mxgraph;
```



这里有两点需要注意的

- `mx` 方法传入的配置项 `mxBasePath` 指向的路径一定要是一个可以通过 url 访问的静态资源目录。举个例子，pokemon-diagram 的 static 目录 https://github.com/jinzhanye/pokemon-diagram/tree/master/static 是个静态资源目录，该目录下有 `mxgraph/css/common.css` 这么个资源，通过`http://localhost:7777` 可以访问 pokemon-diagram 应用，那么通过 `http://localhost:7777/static/mxgraph/css/common.css` 也应该是可以访问 `common.css` 才对

- 如果你是通过 script 标签引入 mxGraph，是不需要绑定全局变量那段代码的。模块化引入要使用这段代码是因为，mxGraph 这个框架有些代码是通过 window.mxXXX 对以上属性进行访问的，如果不做全局绑定使用起来会有点问题。这是官方一个未修复的 BUG，详情可以查阅上面代码注释的 issue

## 基础知识
这部分会使用到我自己编写的一些例子 https://github.com/jinzhanye/mxgraph-demos 。大家可以先把代码下载下来，这些例子都是不需要使用 node 运行的，直接双击打开文件在浏览器运行即可。

### Cell
`Cell` 在 mxGraph 中可以代表`组(Group)`、`节点(Vertex)`、`边(Edge)`，mxCell https://jgraph.github.io/mxgraph/docs/js-api/files/model/mxCell-js.html#mxCell.mxCell 这个类封装了 `Cell` 的操作，本教程不涉及到`组`的内容。下文若出现 `Cell` 字眼可以当作 `节点` 或 `边`。

### 事务
官方的 HelloWorld https://github.com/jgraph/mxgraph/blob/master/javascript/examples/helloworld.html 的例子向我们展示了如何将节点插入到画布。比较引人注意的是 `beginUpdate` 与 `endUpdate` 这两个方法，这两个方法在官方例子中出镜频率非常高，我们来了解一下他们是干嘛用的，嗯，真是只是了解一下就可以了，因为官方对两个方法的描述对入门者来说真的是比较晦涩难懂，而且我在实际开发中基本用不上这两个方法。可以等掌握这个框架基本使用后再回过头来研究。下面的描述来源这个文档 https://jgraph.github.io/mxgraph/docs/tutorial.html，我来简单概括一下有关这两个方法的相关信息。

![4_1](https://gitee.com/yejinzhan/images/raw/master/20200530153421.jpeg)

- `beginUpdate、endUpdate` 用于创建一个事务，一次 `beginUpdate` 必须对应一次 `endUpdate`
- 为了保证，假如 beginUpdate 执行失败，endUpdate 永远不会被调用，`beginUpdate 一定要放到 try 块之外`
- 为了保证，假如 try 块内更新失败，endUpdate 也一定被调用，`beginUpdate一定要放到 finally 块`
- 使用 beginUpdate 与 endUpdate 可提高更新视图性能，框架内部做撤消/重做管理也需要 beginUpdate、endUpdate

按照官方这个说明，如果我不需要撤消/重做功能，是不是可以不使用这两个方法呢。我试着把这两个方法从 HelloWorld 例子的代码中删掉，结果程序还是可以正常运行。

### insertVertex

```js
mxGraph.prototype.insertVertex = function(parent, id, value,
                                          x, y, width, height, style, relative) {

  // 设置 Cell 尺寸及位置信息
  var geometry = new mxGeometry(x, y, width, height);
  geometry.relative = (relative != null) ? relative : false;

  // 创建一个 Cell
  var vertex = new mxCell(value, geometry, style);
  // ...
  // 标识这个 Cell 是一个节点
  vertex.setVertex(true);
  // ...

  // 在画布上添加这个 Cell
  return this.addCell(vertex, parent);
};
```

上面是经简化后的 insertVertex https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.insertVertex 方法。 insertVertex  做了三件事，先是设置几何信息，然后创建一个节点，最后将这个节点添加到画布。insertEdge https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.insertEdge 与 insertVertex 类似，中间过程会调用 `vertex.setEdge(true)` 将 `Cell` 标记为边。从这里我们也可以得知无论`节点`还是`边`在 mxGraph 中都是由 mxCell https://jgraph.github.io/mxgraph/docs/js-api/files/model/mxCell-js.html#mxCell.mxCell 类表示，只是在该类内部标识当前 `Cell` 是 `节点` 还是 `边`。

### mxGeometry

```js
function mxGeometry(x,y,width,height){}
```
mxGeometry https://jgraph.github.io/mxgraph/docs/js-api/files/model/mxGeometry-js.html#mxGeometry.mxGeometry 类表示 `Cell` 的几何信息，宽高比较好理解，只对节点有意义，对边没意义。下面通过 02.geometry.html https://github.com/jinzhanye/mxgraph-demos/blob/master/src/02.geometry.html 这个例子说明如`x、y`的作用。

![4](https://gitee.com/yejinzhan/images/raw/master/20200530152211.jpeg)

`mxGeometry ` 还有一个很重要的布尔属性 `relative`，

- **`relative` 为 `false` 的节点，表示以画布左上角为基点进行定位，`x、y` 使用的是`绝对单位`**

	上一小节提到 `insertVertex` 内部会创建 `mxGeometry` 类。使用 `mxGraph.insertVertex` 会创建一个 `mxGeometry.relative` 为 false 的节点，如 A 节点
	
	![](https://gitee.com/yejinzhan/images/raw/master/20200530152616.png)	

- **`relative` 为 `true` 的节点，表示以父节点左上角为基点进行定位，`x、y` 使用的是`相对单位`**

	使用 `mxGraph.insertVertex` 会创建一个 relative 为 false 的节点。如果你要将一个节点添加到另一个节点中需要在该方法调用的第9个参数传入 `true`，将 `relative` 设置为 `true`。这时子节点使用相对坐标系，以父节点左上角作为基点，x、y 取值范围都是 `[-1,1]`。如 C节点 相对 B节点定位。

![6](https://gitee.com/yejinzhan/images/raw/master/20200530152709.png)

- **`relative` 为 `true` 的边，`x、y` 用于定位 label**

	使用 `mxGraph.insertEdge` 会创建一条 relative 为 true 的边。x、y 用于定位线条上的 label，x 取值范围是 `[-1,1]`，`-1 为起点，0 为中点，1 为终点`。y 表示 label 在边的正交线上移到的距离。第三个例子能帮忙大家理解这种情况。
  ![7](https://gitee.com/yejinzhan/images/raw/master/20200530152733.jpeg)
	
	```js
	const e1 = graph.insertEdge(parent, null, '30%', v1, v2);
	e1.geometry.x = 1;
	e1.geometry.y = 100;
	```

### 设置样式
![8](https://gitee.com/yejinzhan/images/raw/master/20200530152743.png)

由 03.stylesheet.html https://github.com/jinzhanye/mxgraph-demos/blob/master/src/03.stylesheet.html 这个例子我们得知 mxGraph 提供两种设置样式的方式。

第一种是设置`全局样式`。mxStylesheet https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxStylesheet-js.html#mxStylesheet.mxStylesheet 类用于管理图形样式，通过 graph.getStylesheet() https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.getStylesheet 可以获取当前图形的 `mxStylesheet` 对象。`mxStylesheet` 对象的 `styles` 属性也是一个对象，该对象默认情况下包含两个对象`defaultVertexStyle、defaultEdgeStyle`，修改这两个对象里的样式属性`对所有线条/节点都生效`。

第二种是`命名样式`。先创建一个样式对象，然后使用 mxStylesheet.putCellStyle https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxStylesheet-js.html#mxStylesheet.putCellStyle 方法为 `mxStylesheet.styles` 添加该样式对象并命名。在添加 Cell 的时候，将样式写在参数中。格式如下

```
[stylename;|key=value;]
```

分号前可以跟命名样式名称或者一个样式的 key、value 对。

`ROUNDED` 是一个内置的命名样式，对节点设置有圆角效果，对边设置则边的拐弯处为圆角。

例子中设置折线有一个需要注意的地方。

```js
// 设置拖拽边的过程出现折线，默认为直线
graph.connectionHandler.createEdgeState = function () {
  const edge = this.createEdge();
  return new mxCellState(graph.view, edge, graph.getCellStyle(edge));
};
```

虽然调用 `insertEdge` 方法时已经设置了线条为折线，但是在拖拽边过程中依然是直线。上面这段代码重写了 createEdgeState https://jgraph.github.io/mxgraph/docs/js-api/files/handler/mxConnectionHandler-js.html#mxConnectionHandler.createEdgeState 方法，将拖动中的边样式设置成与静态时的边样式一致，都是折线。

#### 查看样式效果小技巧
mxGraph 所有样式在这里 https://jgraph.github.io/mxgraph/docs/js-api/files/util/mxConstants-js.html#mxConstants.STYLE_STROKECOLOR 可以查看，打开网站后可以看到以 `STYLE_` 开头的是样式常量。但是这些样式常量并不能展示样式的效果。下面教大家一个查看样式效果的小技巧，使用 https://www.draw.io 或 GraphEditor https://jgraph.github.io/mxgraph/javascript/examples/grapheditor/www/index.html (这两个应用都是使用 mxGraph 进行开发的) 的 `Edit Style` 功能可以查看当前 Cell 样式。

比如现在我想将边的样式设置成：折线、虚线、绿色、拐弯为圆角、粗3pt。在 Style 面板手动修改样式后，再点击 `Edit Style` 就可以看到对应的样式代码。

![9](https://gitee.com/yejinzhan/images/raw/master/20200530152828.jpeg)

![10](https://gitee.com/yejinzhan/images/raw/master/20200530152757.jpeg)

为了方便观察我手动格式化了样式，注意最后一行以 `entry` 或 `exit` 开头的样式代表的是边出口/入口的靶点坐标，下一小节会进行讲解。


### 靶点
关于如何设置靶点可以参考 04.anchors.html https://github.com/jinzhanye/mxgraph-demos/blob/master/src/04.anchors.html ，下面也是以这个 Demo 进行讲解两个用户操作的例子，对比不同的操作对于获取靶点信息的影响。

将鼠标悬浮中 A 节点中心，待节点高亮时连接到 B 节点的一个靶点上

![11](https://gitee.com/yejinzhan/images/raw/master/20200530152901.jpeg)

![12](https://gitee.com/yejinzhan/images/raw/master/20200530152907.jpeg)

然后将 A 节点拖拽到 B 节点右边

![13](https://gitee.com/yejinzhan/images/raw/master/20200530152918.jpeg)

可以看到如果从图形中心拖出线条，这时边的出口值 `exit` 为空，只有入口值 `entry`。如果拖动节点 mxGraph 会智能地调整线条出口方向。如节点 A 的连接靶点原来是在右边，节点拖动到节点 B 右边后靶点也跟着发生了变化，跑到了左边，而节点 B 的连接靶点一直没变。

这次将鼠标悬浮到 A 节点的一个靶点，待靶点高亮时连接到 B 节点的一个靶点上

![14](https://gitee.com/yejinzhan/images/raw/master/20200530152929.jpeg)

![15](https://gitee.com/yejinzhan/images/raw/master/20200530152943.jpeg)

然后将 A 节点拖拽到 B 节点右边

![16](https://gitee.com/yejinzhan/images/raw/master/20200530153000.jpeg)

可以看到这次所有值都有了，连接后拖动节点 A，连接靶点的位置也固定不变，mxGraph 不像第一个例子一样调整连接靶点位置。之所以产生这样的差异是因为第一个例子的边是从节点中心拖出的，并没有出口靶点的信息，而第二个例子则是明确地从一个靶点中拖出一条边。


### 面向对象编程
mxGraph 框架是使用面向对象的方式进行编写的，该框架所有类带 mx 前缀。在接下来的例子你会看到很多这种形式的方法`重写(Overwrite)`。

```js
const oldBar =  mxFoo.prototype.bar;
mxFoo.prototype.bar = function (...args)=> {
   // .....
	oldBar.apply(this,args);
	// .....
};
```

### 节点组合

这一小节通过 05.consistuent.html https://github.com/jinzhanye/mxgraph-demos/blob/master/src/05.consistuent.html 这个例子，讲解节点组合需要注意的地方。

组合节点后默认情况下，父节点是可折叠的，要关闭折叠功能需要将 `foldingEnabled` 设为 `false`。

```js
graph.foldingEnabled = false;
```

如果希望在改变父节点尺寸时，子节点与父节点等比例缩放，需要开启 `recursiveResize`。

```js
graph.recursiveResize = true;
```

下面是这个例子最重要的两段代码。

```js
/**
 * Redirects start drag to parent.
 */
const getInitialCellForEvent = mxGraphHandler.prototype.getInitialCellForEvent;
mxGraphHandler.prototype.getInitialCellForEvent = function (me) {
  let cell = getInitialCellForEvent.apply(this, arguments);
  if (this.graph.isPart(cell)) {
    cell = this.graph.getModel().getParent(cell);
  }
  return cell;
};

// Redirects selection to parent
graph.selectCellForEvent = function (cell) {
  if (this.isPart(cell)) {
    mxGraph.prototype.selectCellForEvent.call(this, this.model.getParent(cell));
    return;
  }

  mxGraph.prototype.selectCellForEvent.apply(this, arguments);
};
```

这两个方法`重写(Overwrite)`了原方法，思路都是判断如果该节点是子节点则替换成父节点去执行剩下的逻辑。

getInitialCellForEvent https://jgraph.github.io/mxgraph/docs/js-api/files/handler/mxGraphHandler-js.html#mxGraphHandler.getInitialCellForEvent 在鼠标按下(mousedown事件，不是click事件)时触发，如果注释掉这段代码，不使用父节点替换，当发生拖拽时子节点会被单独拖拽，不会与父节点联动。使用父节点替换后，原本子节点应该被拖拽，现在变成了父节点被拖拽，实现联动效果。

selectCellForEvent https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.selectCellForEvent 其实是 `getInitialCellForEvent` 内部调用的一个方法。这个方法的作用是将 cell 设置为 `selectionCell`，设置后可通过 mxGraph.getSelectionCell https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.getSelectionCell 可获取得该节点。与 `getInitialCellForEvent` 同理，如果不使用父节点替换，则 `mxGraph.getSelectionCell ` 获取到的会是子节点。项目实战我们会使用到 `mxGraph.getSelectionCell ` 这个接口。

至此理论部分讲解完毕，下篇文章我们将进行项目实战，敬请期待！

## 参考
- mxGraph Tutorial https://jgraph.github.io/mxgraph/docs/tutorial.html
- mxGraph User Manual – JavaScript Client https://jgraph.github.io/mxgraph/docs/manual.html
- mxGraph API Specification https://jgraph.github.io/mxgraph/docs/js-api/files/index-txt.html
- mxGraph Javascript Examples https://jgraph.github.io/mxgraph/javascript/index.html
