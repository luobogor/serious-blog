---
title: 流量漫游指南：从 CloudFlare 到 Dokploy
date: 2025-11-27 14:54:28
categories: 建站
---

本文带你了解流量如何从 CloudFlare 到 Dokploy 应用容器。下图展示了请求的完整生命周期：

```mermaid
graph TD
    %% 样式定义
    classDef user fill:#f9f,stroke:#333,stroke-width:2px,color:black;
    classDef cf fill:#fa8,stroke:#333,stroke-width:2px,color:black;
    classDef vps fill:#8df,stroke:#333,stroke-width:2px,color:black;
    classDef traefik fill:#8f8,stroke:#333,stroke-width:2px,color:black;
    classDef app fill:#ddd,stroke:#333,stroke-width:2px,color:black;

    %% 节点
    User((👤 用户浏览器)):::user
    CF[☁️ Cloudflare CDN]:::cf
    VPS[🖥️ VPS 服务器]:::vps
    Traefik["🚦 Dokploy 网关 (Traefik)"]:::traefik
    App[📦 你的应用容器]:::app

    %% 流程
    User -- "1. 发起请求 (mydomain.com)" --> CF
    CF -- "2. 转发流量 (公网 IP)" --> VPS
    VPS -- "3. 端口映射 (443/80)" --> Traefik
    Traefik -- "4. 内部路由转发" --> App

    %% 子图结构
    subgraph "Docker 内部网络"
        Traefik
        App
    end
```

**流程详解：**

1.  **用户发起请求**：
    用户在浏览器输入域名，请求首先到达离用户最近的 **Cloudflare 边缘节点**。此时，Cloudflare 作为第一层代理，负责接收用户的连接。

2.  **Cloudflare 转发**：
    Cloudflare 根据 DNS 设置，将请求通过公网转发给你的 **VPS 服务器 IP**。

3.  **VPS 接收与映射**：
    流量到达 VPS 后，操作系统根据防火墙规则，将访问 80 (HTTP) 或 443 (HTTPS) 端口的流量，直接映射给正在监听这些端口的 **Dokploy 网关容器 (Traefik)**。

4.  **Traefik 内部路由**：
    Traefik 是 Dokploy 的核心“交通指挥官”。它收到请求后，会检查请求的域名（Host），并在 Docker 内部网络中找到对应的 **应用容器**（比如你的 Next.js 或 Java 服务），最后将请求精准地送达应用内部。
