---
title: 腾讯云国内服务器极速安装 Dokploy 避坑指南
date: 2026-04-19 17:05:00
categories: 建站
---

最近想在腾讯云服务器上折腾一下 Dokploy（一个非常好用的开源 Vercel/Heroku 替代品），结果一上来就踩坑了。因为国内网络环境的原因，直接跑官方的安装脚本，绝对会卡在 `Pulling images` 这一步，死活拉不下 Docker 镜像。

调研了一下，其实只要利用好腾讯云自带的内网镜像源，再搭配几个国内优质的公共源，就能完美解决这个问题。今天就来复盘一下这套“组合拳”，帮你 0 到 1 极速搞定 Dokploy 安装。

## 系统模板选择
准备安装 Dokploy 的第一步，是在腾讯云控制台重装系统或购买服务器时，直接在应用镜像（或系统镜像）里选择 **Docker CE** 镜像。这样系统初始化后就自带了 Docker 环境，省去了我们手动安装 Docker 的麻烦，直接进入正题。

## 测试内网镜像源
说一些踩过的坑，很多网上的教程让你随便找个国内源填上去，结果要么失效，要么速度极慢。其实腾讯云自带了一个**内网专属镜像源**（`mirror.ccs.tencentyun.com`），走内网通道，速度极快且不耗费公网流量！

在动手配置前，我们可以先在终端测试一下这个内网源是否对你的服务器可用：

```bash
curl -I https://mirror.ccs.tencentyun.com/v2/
```

只要终端秒回类似 `HTTP/1.1 200 OK` 的 Header 信息，就说明内网源网络完全畅通，稳了！

## 配置 Docker 镜像源
接下来就是重头戏，一键配置 `/etc/docker/daemon.json`。为了防止内网源偶尔抽风或者缺少最新镜像，我们把腾讯云内网源和两个目前实测好用的公共源（毫秒镜像和轩辕镜像）组合起来用。

直接在终端复制粘贴并执行以下命令：

```bash
# 1. 创建 docker 配置目录
sudo mkdir -p /etc/docker

# 2. 写入镜像源配置（包含腾讯云内网源和备用公共源）
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me"
  ]
}
EOF

# 3. 重载配置并重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

一套组合拳打下来，两个字：丝滑！再也不用担心国内服务器拉取镜像卡半天了。

配置完成后，可以顺手查看一下配置是否成功写入：

```bash
cat /etc/docker/daemon.json
```

如果返回内容是以上配置的镜像源，说明配置成功！

## 一键安装 Dokploy
网络痛点解决后，剩下的就非常简单了。直接使用 Dokploy 官方的安装脚本，一把梭哈：

```bash
export DOKPLOY_VERSION=latest && curl -sSL https://dokploy.com/install.sh | bash
```

细心的朋友可能会发现，官网教程结尾写的是 `| sh`，但我这里特意改成了 `| bash`。

说一些踩过的坑，腾讯云常用的 Ubuntu 系统中，默认的 `sh` 实际上软链接到了 `dash`（一个非常轻量但阉割了部分高级语法的 Shell）。而 Dokploy 的安装脚本比较复杂，里面用到了一些 Bash 专属的扩展语法（比如 `[[ ]]` 高级条件判断或数组操作）。如果直接用 `sh` 跑，大概率会直接报错 `Syntax error` 让你怀疑人生。所以，明确指定交给 `bash` 执行才是最稳妥的姿势。

![result.png](/images/install-dokploy-on-tencent-cloud/result.png)

因为配置了内网加速源，你会发现拉取 `dokploy`、`postgres`、`redis` 和 `traefik` 等核心镜像的速度飞快。稍等片刻，看到绿色的 `Success` 提示，就说明安装大功告成了！

最后，别忘了在腾讯云的安全组里放行 `3000` 端口，然后在浏览器输入 `http://你的服务器IP:3000`，就可以愉快地开始部署你的应用啦。发就完了！ 🤣