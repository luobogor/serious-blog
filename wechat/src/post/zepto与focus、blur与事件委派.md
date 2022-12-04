![image](https://tva1.sinaimg.cn/large/007S8ZIlgy1gf53ao51dpj30m80eu4eu.jpg)

--- | focusin、focusout | focus、blur 
--- | --- | ---
冒泡支持 | 支持 | 不支持
浏览器支持 | 现在所有浏览器都支持，但以前firefox52以下不支持 | 所有浏览器都支持


## 注册focus事件
以下是经简化后zepto处理注册focus事件的代码。运行代码，可以观察到当input获得焦点时触发了form注册focus时的回调函数。

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>foucus事件委派</title>
</head>
<body>
<div>
    <form action="" style="padding: 50px;background-color: #00b4fd;width: 200px;height: 200px">
        <input type="text" value="helloworld">
    </form>
</div>
</body>
<script>
	//除了IE,其他浏览器的window对象中都没有onfocusin属性，但是其他浏览器addEventListener('focusin')有效
    var focusinSupported = 'onfocusin' in window,
        form = document.forms[0],
        focus = {focus: 'focusin', blur: 'focusout'}

    function callback(event) {
    	 console.log(event.target.tagName)//INPUT
        console.log(event.type,event.bubbles)//event.bubbles为false表明当前事件不会向上冒泡
        this.style.background = "red"
    }

    //当type为focus且浏览器支持onfocusin，则focus -> focusin
    function realEvent(type) {
        return focusinSupported && focus[type] || type
    }

    function eventCapture() {
        //不支持onfocusin则在捕获阶段触发事件
        return !focusinSupported ? true : false
    }

    form.addEventListener(realEvent('focus'), callback, eventCapture());
//    form.addEventListener(realEvent('focus'), callback, false);//focus不会向上冒泡，这样写不会触发回调
</script>
</html>	
```

代码比较少，下面说一下重点。

zepto的处理focus事件注册流程大致如下

- `为了有事件冒泡以完成事件委派`，一般情况下zepto用focusin、focusout代替focus、blur
- 在浏览器不支持focusin、focusout的情况下，只能用focus、blur在捕获阶段触发回调，间接做到事件委派。

IE9开始使用DOM事件模型，`zepto统一用addEventListener注册事件`，不支持IE9以下的版本，zepto中的on方法内部调用add方法，add方法经过多步处理，最后是这样注册一个事件的

```js
form.addEventListener(realEvent('focus'), callback, eventCapture());
```

zepto是用以下方式来判断浏览器是否支持focusin事件

```js
var focusinSupported = 'onfocusin' in window
```

除了IE,其他浏览器的window对象中都没有onfocusin属性，其他浏览器中focusinSupported为false，但其他浏览器也支持focusin，用addEventListener('focusin')是有效的。下表是zepto注册focus事件的两个重要判断

--- | IE9+ | FF、Chrome
--- | --- | ---
realEvent | focusinSupported:true， focus 转换为 focusin  | focusinSupported:false，focus 不作转换
eventCapture | false，冒泡阶段触发回调 |  true，捕获阶段触发回调

在捕获阶段获取目标对象同样可以实现事件委派，原因可以参考以下引用
>即使"DOM2级事件"规范明确要求捕获阶段不会涉及事件目标(作者注释：即event.target)，但IE9、Safari、Chrome、Firefox 和 Opera9.5及更高版本都会在捕获阶段触发事件对象上的事件。结果，就是有两个机会在目标对象上面操作事件。
><\<Javascript高级编程>>第三版 13.1.3 DOM事件流 p348

## 注册focusin事件
除了IE9-，在zepto中，其他主流浏览器都可以注册focusin事件

## 总结
现在所有浏览都已经支持foucsin，未来属于支持冒泡的focusin

## 参考
- MDN focusin浏览器支持 https://developer.mozilla.org/en-US/docs/Web/Events/focusin
- <\<Javascript高级编程>>第三版 13.1.3 DOM事件流

<section class="custom-bottom">
  欢迎大家持续关注 Luobo FE，更多精彩文章持续出炉哦～
</section>
