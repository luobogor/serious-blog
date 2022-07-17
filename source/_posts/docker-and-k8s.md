---
title: Docker&k8s 在前端 CICD 中的应用
date: 2022-06-10 18:39:59
categories: 技术
---

![cover.png](/images/docker-and-k8s/cover.png)

## Docker

### 传统构建方式的问题

介绍 Docker 是什么之前，先说下传统构建方式有什么问题：

- 同一环境依赖需要多个版本时得特殊处理：比如一台机器上打包多个项目，鸣人打包螺旋丸项目打包需要 node14 环境，佐助打包千鸟项目打包需要 node16 环境，我们需要另外引入 nvm 解决这个问题
- 无法保证一致的运行环境：明明在测试的时候在 A 机器打包可以，为什么交付到客户那里用 B 机器打包就不行了
- 迁移的成本高：同一个项目搭建多套环境，每台机器都需要重新安装一遍项目所需要的环境依赖
- ...

### Docker 是什么
> Docker 是一个开源的应用容器引擎，让开发者可以打包他们的应用以及依赖包到一个可移植的镜像（Docker Image）中，然后发布到任何流行的 Linux或Windows操作系统的机器上，也可以实现虚拟化。容器（Docker Container）是完全使用沙箱机制，相互之间不会有任何接口。

上面一段描述是来自百度百科的引用，Container、Image 是 Docker 两个重要概念，大白话可以这样理解：

- Container 容器可以粗略理解为一台轻量级的虚拟机，实现环境隔离，也就解决上述传统构建中的问题
- 打个比喻，Image 可以理解为面向对象编程的类，而 Container 可以理解为类（即 Image）的实例化对象

### 使用 Docker 构建前后端项目

#### Dockerfile

Egg 项目：

https://gitee.com/yejinzhan/k8s-demo-backend

```dockerfile
# 拉取 node 镜像
FROM node:14.19.3-alpine3.15
# 将当前目前所有文件拷贝到容器 /k8s-demo-backend 目录
COPY ./ /k8s-demo-backend
# 切换工作目录到 /k8s-demo-backend
WORKDIR /k8s-demo-backend
# 安装依赖
RUN npm install --production --no-package-lock --registry=https://registry.npmmirror.com
# 容器暴露端口，默认为 80
EXPOSE 7001
# 启动容器时执行 npm start
CMD ["npm", "start"]
```

执行下面命令打包镜像并启动容器

- 不指定打包配置文件的话默认使用项目目录下的 `Dockerfile` 作为打包配置
- -t 是给镜像打 tag，tag 默认是 latest，用 npm 包比喻的话，tag 就相当于包的版本。如果要打特定版本的包，比如 v2，可以这么写 `docker image build -t k8s-demo-backend:v2 .`

```shell
# 构建镜像，以当前目录作为构建上下文目录
docker image build -t k8s-demo-backend .
# 将本地的 7002 映射到容器的 7001
docker container run -p 7002:7001 k8s-demo-backend
```

容器启动后通过 http://localhost:7002 便可以访问这个 Egg 应用。注意，Node 服务不要开启守护进程，否则容器启动后会马上停止运行。



Vue 项目：

https://gitee.com/yejinzhan/k8s-demo-frontend

与 Node 服务不一样，这个 Vue 项目打包出来的是静态页面，所以要启一个 nginx 服务来访问

```dockerfile
FROM node:14.19.3-alpine3.15
COPY ./ /k8s-demo-frontend
WORKDIR /k8s-demo-frontend
RUN npm install --no-package-lock --registry=https://registry.npmmirror.com && npm run build

FROM nginx:1.15-alpine
# --from=0 表示将上个阶段的构建产物 /k8s-demo-frontend/dist 拷贝到容器目录 /usr/share/nginx/html
COPY --from=0 /k8s-demo-frontend/dist /usr/share/nginx/html
WORKDIR /usr/share/nginx/html
```

#### .dockerignore

类似 .gitignore，用于 Docker 构建过程中忽略拷贝指定的文件

```
node_modules
dist
Dockerfile
```

#### Docker Hub

https://hub.docker.com/search?q=node 类似公共 npm 仓库，可以在上面下载镜像，也可以发布自己的镜像


## k8s
### k8s 是什么

![k8s架构](/images/docker-and-k8s/architecture.png) (k8s架构)

实际开发我们会有很多个运行的 Docker 容器，k8s 可以帮忙我们更好地管理这些容器，它主要功能如下：
- 容器管理：创建、启动、删除容器等
- 平滑发布、回滚
- 弹性伸缩：包括人工伸缩、自动伸缩
- 负载均衡：
    - Ingress 代理 Service
    - Service 代理 Pod

### Deployment

Deployment 是 k8s 一个重要的组件，主要用于创建 Pod、滚动升级、回滚应用、扩容、缩容等等。Pod 是一个容器组，里面有很多容器，容器组内共享资源。
- 一个 Pod 一般只运行一个应用服务，比如下面 `containers` 声明了运行 `frontend-app`。
- `replicas` 控制 Pod 数量。下面的配置 `replicas` 为 4，表示创建 4 个 `frontend-app`。
- `image` 是应用镜像地址

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-frontend
spec:
  selector:
    matchLabels:
      app: demo-frontend
  replicas: 4
  template:
    metadata:
      labels:
        app: demo-frontend
    spec:
      imagePullSecrets:
      - name: private-registry
      containers:
      - name: frontend-app
        imagePullPolicy: Always
        image: 120.77.137.109:8082/frontend-app
        ports:
        - containerPort: 80
```

如图所示，我们使用 `kubectl get pod -o wide` 列出当前集群的 Pod，然后通过 `curl podId` 访问 Pod。

![img_6.png](/images/docker-and-k8s/img_6.png)

一个 Pod 拥有一个 IP。但这个 IP 会随着 Pod 的重启、创建、删除等跟着改变，不固定且不完全可靠，这也就是 Pod 的 IP 漂移问题。要解决这个问题，我们可以使用下面介绍的 Service 做代理访问 Pod。

### Service
Service 的类型有好几种，这里主要讲 `ClusterIP`，`ClusterIP` 表示部署的这个 Service 会获得一个集群内唯一的 IP，通过这个 IP 我们可以在集群内任何一台机器访问这个 Service。

下面配置表示声明一个名为 `demo-frontend-service` 的 Service，通过 Service 可以访问 `demo-frontend`。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-frontend-service
spec:
  type: ClusterIP
  selector:
    app: demo-frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

但是这个 IP 只能在集群内访问，如果要在外网访问 Service，我们可以借助接下来介绍的 `ingress-nginx`。

### ingress-nginx
ingress-nginx 实质上是一个 Deployment，内部运行 nginx。编写的代理规则也会被转换成 nginx 配置。通过 ingress-nginx 代理可以访问不同的 Service，也可以做负载均衡。

下面来看个例子，ingress-nginx 配置两个规则：

1. 通过 http://ip:port 访问 demo-frontend-service
2. 通过 http://ip:port/api 访问 demo-backend-service

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-demo-frontend
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - http:
      paths:
       - path: /
         pathType: ImplementationSpecific
         backend:
           service:
             name: demo-frontend-service
             port:
               number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-demo-backend
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - http:
      paths:
       - path: /api/(.*)
         pathType: Prefix
         backend:
           service:
             name: demo-backend-service
             port:
               number: 7001
```

应用上述配置成功启动 ingress-nginx 之后，如下图所示使用 `kubectl get svc -n ingress-nginx` 命令可以查看 ingress-nginx service 运行情况。通过集群内任意一个 Node 的 ip 加 31234 端口，就可以访问我们配置的服务，如 http://120.77.137.109:31234/api 。

![img_5.png](/images/docker-and-k8s/img_5.png)

接下来我们验证下 ingress-nginx 内部运行 nginx 这个事情。通过`kubectl get pod -n ingress-nginx` 可以列出 ingress-nginx pod 相关信息 ，再执行以下命令进入 ingress-nginx pod 内部看看。

```shell
# kubectl exec pod名称 -n 命名空间 -it -- /bin/sh
kubectl exec ingress-nginx-controller-76c5448f78-q4kpk -n ingress-nginx -it -- /bin/sh
cat nginx.conf
```

如下图所示，可以看到上文配置的 `/api` 规则被转换成 nginx 反向代理规则。
![img_7.png](/images/docker-and-k8s/img_7.png)


### 灰度发布
所谓灰度发布，简单理解就是不同用户群访问同一个地址，响应不同的服务。简单应用如下配置就可以在 k8s 中实现灰度发布。当用户代理访问 http://ip:port 携带 key 为 `users_from_Shenzhen` 值为 `always` 的  cookie 时，命中配置规则，服务指向 demo-frontend-grey-service，否则指向上文提到的 demo-frontend-service。

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-demo-canary
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-cookie: "users_from_Shenzhen"
spec:
  rules:
  - http:
      paths: 
       - backend:
          serviceName: demo-frontend-grey-service
          servicePort: 80
  backend:
     serviceName: demo-frontend-grey-service
     servicePort: 80
```

### 滚动更新
策略定义为 RollingUpdate 的 Deployment。滚动更新通过逐个替换实例来逐步部署新版本的应用，直到所有实例都被替换完成为止，会有新版旧版同时存在的情况。

```yaml
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
```

上述更新策略执行结果如下图所示，先将版本 V2 部署完成，然后将流量入口切换到 V2，最后销毁旧版本 V1，做到让用户无感更新。

![rolling-update.png](/images/docker-and-k8s/rolling-update.png)

### 服务发现
平时我们输入域名访问网站的时候，都会先经过 DNS 解析，得知服务 IP 后访问网站，这就是一个服务发现的过程。而在 K8S 中，CoreDNS 充当解析 Service 域名的角色。

CoreDNS 将集群中的 Service 名称和 IP 做配，集群中 Service 和 Service 需要通信，他们互相调用他们在集群中的名称就可以了。如果 Service 的 IP 发生改变，他们的名称也不会变化，也就是为了方便好记，也防止了在代码里因为服务在集群内 IP 发生变化重复修改 IP 的尴尬。

Service 域名映射规则：[ServiceName].[NameSpace].svc.cluster.local，通过以下命令我们可以验证服务发现。

``` shell
# 进入容器内部
kubectl exec -it front-v1-bdfd88666-4cskk -- /bin/sh

# 在容器内通过域名访问其他 Service
curl http://[ServiceName].[NameSpace].svc.cluster.local
# 比如
curl http://demo-backend-service.default.svc.cluster.local:7001/say-hello
curl http://demo-frontend-service.default.svc.cluster.local
```

CoreDNS 是安装 k8s 的时候预装好了，可以通过以下命令查看 CoreDNS 安装情况。

```shell
kubectl -n kube-system get all  -l k8s-app=kube-dns -o wide
```

![coredns.png](/images/docker-and-k8s/coredns.png)

也可以通过安装 busybox，在终端查询域名对应的 IP。

```shell
kubectl exec busybox -- nslookup demo-backend-service.default
```

### 实际生产架构案例
以下是一个 B 端管理后台运维架构，有助于我们更好地理解 k8s。阿里云 SLB 将流量先打到生产集群，生产集群再根据灰度代理配置将流量分到不同的集群。

![实际生产架构案例](/images/docker-and-k8s/prod-architecture.jpg)



## Jenkins 部署一个前后端分离项目

文章最后，我们使用 Jenkins 部署一个前后端分离项目，把上文所有东西串起来。先配置 git。
![img.png](/images/docker-and-k8s/img.png)



编写脚本，在 git 拉取代码后执行。
![img_1.png](/images/docker-and-k8s/img_1.png)

```shell
#!/bin/sh -l

time=$(date "+%Y%m%d%H%M%S")
# 打包 docker 镜像
docker build -t 120.77.137.109:8082/frontend-app:$time .
# 登录私有仓库，120.77.137.109:8082 是镜像库地址
docker login -u $DOCKER_LOGIN_USERNAME -p $DOCKER_LOGIN_PASSWORD 120.77.137.109:8082
# 将镜像推送到私有仓库
docker push 120.77.137.109:8082/frontend-app:$time
# 触发 k8s 从私有仓库拉取最新镜像更新项目
kubectl --kubeconfig=k8s-config.yaml set image deployment/demo-frontend frontend-app=120.77.137.109:8082/frontend-app:$time
```

点击构建后，查看控制台输出的日志。

![img_2.png](/images/docker-and-k8s/img_2.png)
![img_3.png](/images/docker-and-k8s/img_3.png)

## 参考
- [从 0 到 1 实现一套 CI/CD 流程](https://juejin.cn/book/6897616008173846543/section/6897634827311251471)
- [尚硅谷 Kubernetes 视频教程](https://www.bilibili.com/video/BV1c4411y71Q)
- [Kubernetes 文档](http://docs.kubernetes.org.cn/)
- [Docker 文档](https://dockerdocs.cn/get-started/overview/index.html)

