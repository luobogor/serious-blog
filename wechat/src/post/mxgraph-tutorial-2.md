书接上回，这次我们进行 mxGraph 项目实战，这部分我主要挑一些这个项目 https://github.com/jinzhanye/pokemon-diagram 比较重要的点进行讲解。

## 写一个节点组合
下面以项目的这个节点为例，讲解如何组合节点

![17](https://gitee.com/yejinzhan/images/raw/master/20200530153022.jpeg)


```js
const insertVertex = (dom) => {
  // ...
  const nodeRootVertex = new mxCell('鼠标双击输入', new mxGeometry(0, 0, 100, 135), `node;image=${src}`);
  nodeRootVertex.vertex = true;
  // ...
  
  const title = dom.getAttribute('alt');
  const titleVertex = graph.insertVertex(nodeRootVertex, null, title,
    0.1, 0.65, 80, 16,
    'constituent=1;whiteSpace=wrap;strokeColor=none;fillColor=none;fontColor=#e6a23c',
    true);
  titleVertex.setConnectable(false);

  const normalTypeVertex = graph.insertVertex(nodeRootVertex, null, null,
    0.05, 0.05, 19, 14,
    `normalType;constituent=1;fillColor=none;image=/static/images/normal-type/forest.png`,
    true);
  normalTypeVertex.setConnectable(false);
  // .....
};
```

单单 `nodeRootVertex` 就是长这个样子。通过设置自定义的 `node` 样式(见 Graph https://github.com/jinzhanye/pokemon-diagram/blob/master/src/graph/Graph.js 类 _putVertexStyle 方法)与 `image` 属性设置图片路径配合完成。

![18](https://gitee.com/yejinzhan/images/raw/master/20200530153031.jpeg)

因为默认情况下一个节点只能有一个文本区和一个图片区，要增加额外的文本和图片就需要组合节点。在 `nodeRootVertex` 上加上 `titleVertex` 文本节点和 `normalTypeVertex` 图片节点，最终达到这个效果。

![19](https://gitee.com/yejinzhan/images/raw/master/20200530153125.jpeg)


有时需要为不同子节点设置不同的鼠标悬浮图标，如本项目鼠标悬浮到 `normalTypeVertex ` 时鼠标变为手形，参考 AppCanvas.vue 的 setCursor 方法，重写 `mxGraph.prototype.getCursorForCell` 可以实现这个功能。

```js
const setCursor = () => {
  const oldGetCursorForCell = mxGraph.prototype.getCursorForCell;
  graph.getCursorForCell = function (...args) {
    const [cell] = args;
    return cell.style.includes('normalType') ?
      'pointer' :
      oldGetCursorForCell.apply(this, args);
  };
};
```

#### 编辑内容
下面这段代码是编辑内容比较常用的设置

```js
// 编辑时按回车键不换行，而是完成输入
this.setEnterStopsCellEditing(true);
// 编辑时按 escape 后完成输入
mxCellEditor.prototype.escapeCancelsEditing = false;
// 失焦时完成输入
mxCellEditor.prototype.blurEnabled = true;
```

默认情况下输入内容时如果按回车键内容会换行，但有些场景有禁止换行的需求，希望回车后完成输入，通过 graph.setEnterStopsCellEditing(true) https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.setEnterStopsCellEditing 设置可以满足需求。

重点说说 mxCellEditor.prototype.blurEnabled https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxCellEditor-js.html#mxCellEditor.blurEnabled 这个属性，默认情况下如果用户在输入内容时鼠标点击了画布之外的不可聚焦区域(div、section、article等)，节点内的编辑器是不会失焦的，这导致了 LABEL_CHANGED https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.mxEvent.LABEL_CHANGED 事件不会被触发。但在实际项目开发中一般我们会期望，如果用户在输入内容时鼠标点击了画布之外的地方就应该算作完成一次输入，然后通过被触发的 `LABEL_CHANGED` 事件将修改后的内容同步到服务端。通过 `mxCellEditor.prototype.blurEnabled = true` 这行代码设置可以满足我们的需求。

#### 可换行的 label
````js
const titleVertex = graph.insertVertex(nodeRootVertex, null, title,
      0.1, 0.65, 80, 16,
      'constituent=1;whiteSpace=wrap;strokeColor=none;fillColor=none;fontColor=#e6a23c',
      true);
````

对于非输入的文本内容，默认情况下即便文本超出容器宽度也是不会换行的。我们项目中宽度为 80 的 titleVertex 正是这样一个例子。

![20](https://gitee.com/yejinzhan/images/raw/master/20200530153148.jpeg)

要设置换行需要做两件事，第一是通过这行代码 [mxGraph.setHtmlLabels(true)](https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.setHtmlLabels)，使用 html 渲染文本(mxGraph 默认使用 svg的text 标签渲染文本)。第二是像上面的 titleVertex 的样式设置一样，添加一句 [whiteSpace=wrap](https://jgraph.github.io/mxgraph/docs/js-api/files/util/mxConstants-js.html#mxConstants.STYLE_WHITE_SPACE)。

![21](https://gitee.com/yejinzhan/images/raw/master/20200530153159.jpeg)

## Model
现在介绍一下 Model 这个概念，Model 是当前图形的数据结构化表示。mxGraphModel https://jgraph.github.io/mxgraph/docs/js-api/files/model/mxGraphModel-js.html 封装了 Model 的相关操作。

你可以启动项目，画一个这样的图，然后点击输出XML。为了保的 xml 与下面的一致，需要先拖出智爷，再拖出超级皮卡丘，最后连接边。

![22](https://gitee.com/yejinzhan/images/raw/master/20200530153219.jpeg)

控制台应该输出这样一份 xml

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="4" value="Hello" style="node;image=/static/images/ele/ele-005.png" vertex="1" data="{&quot;id&quot;:1,&quot;element&quot;:{&quot;id&quot;:1,&quot;icon&quot;:&quot;ele-005.png&quot;,&quot;title&quot;:&quot;智爷&quot;},&quot;normalType&quot;:&quot;water.png&quot;}" parent="1">
      <mxGeometry x="380" y="230" width="100" height="135" as="geometry"/>
    </mxCell>
    ........
  </root>
</mxGraphModel>
```

每一个 mxCell 节点都有 parent 属性指向父节点。我们对 value="Hello" 这个 mxCell 节点手动格式化。

```xml
<mxCell 
    id="4" 
    value="Hello" 
    style="node;image=/static/images/ele/ele-005.png" 
    vertex="1" 
    data="{&quot;id&quot;:1,&quot;element&quot;:{&quot;id&quot;:1,&quot;icon&quot;:&quot;ele-005.png&quot;,&quot;title&quot;:&quot;智爷&quot;},&quot;normalType&quot;:&quot;water.png&quot;}" 
    parent="1">
  <mxGeometry 
    x="380" 
    y="230" 
    width="100" 
    height="135" as="geometry"/>
</mxCell>
```

data 值是原对象经 JSON.stringify 得到的，经转义后就变成了上面的样子。控制台还打印了一个 mxGraphModel 对象，对比上面的 xml 与 下图的节点对象，可以发现它们只是同一个 Model 的不同表现形式，xml 正是将 mxGraph.model https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.model 格式化而成的。

![23](https://gitee.com/yejinzhan/images/raw/master/20200530153229.jpeg)

## 事件
本项目监听事件写在 AppCanvas.vue https://github.com/jinzhanye/pokemon-diagram/blob/master/src/pages/AppCanvas.vue 的 _listenEvent 方法，可以在这个方法了解一些常用的事件。下图来自 mxGraph https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph 类的方法调用依赖图，我们可以从这里看出整个框架的事件流动。

![24](https://gitee.com/yejinzhan/images/raw/master/20200530153243.png)

#### 监听事件

本项目的 _listenEvent 方法用到两个事件监听对象。

- mxGraph https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html 继承自 mxEventSource https://jgraph.github.io/mxgraph/docs/js-api/files/util/mxEventSource-js.html#mxEventSource.mxEventSource，使用父类的 addListener https://jgraph.github.io/mxgraph/docs/js-api/files/util/mxEventSource-js.html#mxEventSource.addListener 方法可以将自身当作一个事件中心进行订阅/广播事件。

- mxGraph.getSelectionModel() https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.getSelectionModel 返回一个 mxGraphSelectionModel https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraphSelectionModel-js.html#mxGraphSelectionModel.mxGraphSelectionModel 对象，这个对象也是继承自 `mxEventSource` 有 `mxEvent.UNDO、mxEvent.CHANGE` 两个事件，通过监听 `mxEvent.CHANGE` 事件可以获取当前被选中的 `Cell`。

#### ADD\_CELLS 与 CELLS\_ADD 的区别
![26](https://gitee.com/yejinzhan/images/raw/master/20200530153315.jpeg)

`mxGraph` 类有很多 `XXX_CELLS`、`CELLS_XXXED` 这种形式的事件，这部分我还没弄懂，下面仅以添加事件为例探讨这两类事件的区别。

- 添加 `Cell` 的时候会触发两个事件 `ADD_CELLS`、`CELLS_ADDED`， 先触发 `CELLS_ADDED` 后触发 `ADD_CELLS`。
- `ADD_CELLS` 在 `addCells` 方法中触发，而 `CELLS_ADDED` 在 `cellsAdded` 方法中触发。而对于 addCells https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.addCells 与 cellsAdded https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxGraph-js.html#mxGraph.cellsAdded 官方文档的说明并不能体现出两者的区别，再深究下去就要查阅源码了。按经验而言后触发的事件会携带更多的信息，所以平时开发我会监听 `ADD_CELLS` 事件。`MOVE_CELLS、CELLS_MOVED`、`REMOVE_CELLS、CELLS_REMOVED` 等事件与此类似。

#### 监听 Cell 添加事件

从上面的方法调用依赖图中我们可以看到，`insertVertex`、`insertEdge` 最终都被当作 `Cell` 处理，在后续触发的事件也没有对 `节点/边` 进行区分，而是统一当作 `Cell` 事件。所以对于一个 `Cell` 添加事件，需要自己区别是添加了节点还是添加了边。

```js
graph.addListener(mxEvent.CELLS_ADDED, (sender, evt) => {
  const cell = evt.properties.cells[0];
  if (graph.isPart(cell)) {
    return;
  }

  if (cell.vertex) {
    this.$message.info('添加了一个节点');
  } else if (cell.edge) {
    this.$message.info('添加了一条线');
  }
});
```

还有就是对于子节点添加到父节点的情况(如本项目将 titleVertex 、normalTypeVertex 添加到 nodeRootVertex)也是会触发 `Cell` 添加事件的。通常对于这些子节点不作处理，可以像 05.consistuent.html https://github.com/jinzhanye/mxgraph-demos/blob/master/src/05.consistuent.html 一样用一个 `isPart` 判断过滤掉。

#### 自定义事件

上面提到过 mxGraph 继承自 mxEventSource，调用父类的 fireEvent https://jgraph.github.io/mxgraph/docs/js-api/files/util/mxEventSource-js.html#mxEventSource.mxEventSource 可触发自定义事件。下面是一个简单的例子

```js
mxGraph.addListener('自定义事件A',()=>{ 
  // do something .....
});
// 触发自定义事件
mxGraph.fireEvent(new mxEventObject('自定义事件A');
```

在本项目 Graph https://github.com/jinzhanye/pokemon-diagram/blob/master/src/graph/Graph.js 类的 _configCustomEvent 方法我也实现了两个自定义事件。当边开始拖动时会触发 `EDGE_START_MOVE` 事件，当节点开始拖动时会触发 `VERTEX_START_MOVE` 事件。

## 导出图片
mxGraph 导出图片的思路是先在前端导出图形的 xml 及计算图形的宽高，然后将 xml、宽、高，这有三项数据发送给服务端，服务端也使用 mxGraph 提供的 API 将 xml 转换成图片。服务端如果是使用 Java 可以参考官方这个例子 https://github.com/jgraph/mxgraph/blob/master/java/test/com/mxgraph/test/mxImageExportTest.java，下面主要介绍前端需要做的工作。

导出图片可以使用 mxImageExport https://jgraph.github.io/mxgraph/docs/js-api/files/util/mxImageExport-js.html#mxImageExport.mxImageExport 类，该类的文档有一段可以直接拿来使用的代码。

```js
// ...
var xmlCanvas = new mxXmlCanvas2D(root);
var imgExport = new mxImageExport();
imgExport.drawState(graph.getView().getState(graph.model.root), xmlCanvas);

var bounds = graph.getGraphBounds();
var w = Math.ceil(bounds.x + bounds.width);
var h = Math.ceil(bounds.y + bounds.height);

var xml = mxUtils.getXml(root);
// ...
```

但这段代码会将整块画布截图，而不是以最左上角的元素及最右下角的元素作为边界截图。如果你有以元素作为边界的需求，则需要调用 xmlCanvas.translate https://jgraph.github.io/mxgraph/docs/js-api/files/util/mxXmlCanvas2D-js.html#mxXmlCanvas2D.translate 调整裁图边界。

```js
//.....
var xmlCanvas = new mxXmlCanvas2D(root);
xmlCanvas.translate(
      Math.floor((border / scale - bounds.x) / scale),
      Math.floor((border / scale - bounds.y) / scale),
    );
//.....
```

完整截图代码可以参考本项目 Graph https://github.com/jinzhanye/pokemon-diagram/blob/master/src/graph/Graph.js 类的 exportPicXML 方法。

如果节点像我的项目一样使用到图片，而导出来的图片的节点没有图片。可以从两个方向排查问题，先检查发送的 xml 里的图片路径是否是可访问的，如下面是项目“导出图片”功能打印的 xml 里的一个图片标签。

```xml
<image x="484" y="123" w="72" h="72" src="http://localhost:7777/static/images/ele/ele-005.png" aspect="0" flipH="0" flipV="0"/>
```

要保证 `http://localhost:7777/static/images/ele/ele-005.png` 是可访问的。如果图片路径没问题再检查一下使用的图片格式，本来我在公司项目中节点内使用的图片是 svg 格式，导出图片失败，可能是 mxGraph 不支持这个格式，后来换成 png 之后问题就解决了。

还有就是如果导出的图片里的节点的某些颜色跟设置的有差异，那可能是设置样式时写了3位数的颜色像 `#fff`，颜色一定要使用完整的6位，否则导出图片会有问题。

完。

## 参考
- mxGraph Tutorial https://jgraph.github.io/mxgraph/docs/tutorial.html
- mxGraph User Manual – JavaScript Client https://jgraph.github.io/mxgraph/docs/manual.html
- mxGraph API Specification https://jgraph.github.io/mxgraph/docs/js-api/files/index-txt.html
- mxGraph Javascript Examples https://jgraph.github.io/mxgraph/javascript/index.html
