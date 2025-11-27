---
title: Dokploy 迁移避坑指南：从腾讯云香港到马来西亚的折腾实录
date: 2025-11-26 20:54:28
categories: 建站
---

![广州海珠湿地公园](/images/dokploy-migration-notes/cover.png)

## 📝 背景
原本托管在美国 VPS 上的 Dokploy 服务即将到期。考虑到业务发展主要面向国内，需要更低延迟的线路，但又不想折腾繁琐的 ICP 备案，于是初步选定了 **腾讯云香港轻量级服务器** 作为新家。

本以为是一次简单的 `Backup` -> `Restore`，结果却是一场涉及网络质量、SSL 证书限流和数据一致性的连环踩坑之旅。

---

## 🛠️ 第一部分：标准迁移流程

如果你也需要迁移 Dokploy，以下是基础的操作步骤：

1.  **备份旧服务**：在旧 VPS 上对 Dokploy 进行全量备份（Backup）。
2.  **恢复与修复**：在新 VPS 上恢复（Restore）。如果遇到 **400 错误**，这是已知问题，需要重启 Dokploy 服务：
    ```bash
    docker service scale dokploy=0
    # 等待几秒
    docker service scale dokploy=1
    ```
    *(参考：[GitHub Issue #151](https://github.com/Dokploy/dokploy/issues/151))*
3.  **更新服务器 IP**：
    进入 `Web Server 面板 -> Server -> Update Server Ip`。
    *注意：这一步至关重要，否则部署的数据库连接字符串可能仍指向旧 IP，导致连接失败。*
4.  **刷新 Traefik 路由**：
    如果发现域名能 Ping 通 VPS，但无法访问容器内部（curl 报错或 404），通常是 Traefik 配置未刷新。
    *解决方法：* `Web Server 面板 -> Traefik -> Reload`。
5. **重启整个服务**：
---

## 🌩️ 第二部分：基础设施踩坑（网络与成本）

### 1. 腾讯云香港的“晚高峰”魔咒
迁移初期，我选择了腾讯云香港轻量级服务器。
*   **现象**：早上速度飞快，一到晚高峰丢包严重，访问极慢。
*   **原因**：轻量级服务器通常是共享带宽，且回国线路在晚高峰极其拥堵。
*   **尝试方案**：曾考虑上 **腾讯云 EdgeOne** 加速，但基础套餐需 399元/年，加上服务器成本（1080元/年），对于初创项目成本略高。

### 2. 最终方案：马来西亚 Hostering + Cloudflare
经过对比，我决定放弃直连香港，改用 [**Hostering 的马来西亚节点 KMV2**](https://hostinger.com?REFERRALCODE=BAGJINZHALBE)。
*   **优势**：黑五期间价格极具竞争力（约 821元/2年），且地理位置在亚洲，物理距离适中。
*   **网络策略**：配合 Cloudflare CDN。虽然国内访问速度不如直连香港，但胜在**全天候稳定**。

---

## 🔍 第三部分：Traefik 502 Bad Gateway 深度排查

这是本次迁移中最诡异的问题，排查了很久。

### 现象
配置了两个域名指向同一台机器（Dokploy）：
*   `simple-api.mydomain.com` -> **正常访问**
*   `mydomain.com` -> **502 Bad Gateway**

### 排查过程
首先需要查看 Traefik 的核心日志，路径为：
👉 **Web Server -> Traefik -> View Logs**

在日志中，我发现了大量 `429 Rate Limited` 错误：

```log
2025-11-26T08:17:03Z ERR Unable to obtain ACME certificate for domains error="unable to generate a certificate for the domains [minicanva-fe-ydwzlc-e088fa-62-72-6-194.traefik.me]: acme: error: 429 :: POST :: https://acme-v02.api.letsencrypt.org/acme/new-order :: urn:ietf:params:acme:error:rateLimited :: too many certificates (50) already issued for "traefik.me" in the last 168h0m0s, retry after 2025-11-26 09:06:03 UTC: see https://letsencrypt.org/docs/rate-limits/#new-certificates-per-registered-domain" ACME CA=https://acme-v02.api.letsencrypt.org/directory acmeCA=https://acme-v02.api.letsencrypt.org/directory domains=["minicanva-fe-ydwzlc-e088fa-62-72-6-194.traefik.me"] providerName=letsencrypt.acme routerName=minicanva-fe-ydwzlc-router-websecure-9@file rule=Host(minicanva-fe-ydwzlc-e088fa-62-72-6-194.traefik.me)
```

### 根因分析
1.  **默认域名冲突**：Dokploy 创建应用时，会自动生成一个 `xxxxx.traefik.me` 的预览域名。
2.  **公共配额耗尽**：`traefik.me` 是一个公共泛域名，全球大量用户在使用。Let's Encrypt 对同一个主域名每周签发的证书数量有限制（50个）。
3.  **Traefik 阻塞**：Traefik 疯狂尝试为这个废弃的预览域名申请证书并被拒绝，导致 ACME 客户端阻塞，进而无法为我的主域名 `mydomain.com` 申请证书。
4.  **502 的由来**：因为拿不到证书，Traefik 使用了默认的自签名证书，而我的 Cloudflare SSL 设置为 **Full (Strict)**，直接拒绝了自签名证书，报出 502。

### 解决与复盘
我删除了 Dokploy 面板中自动生成的 `traefik.me` 域名。虽然删除后可能因为缓存或冷却期原因没有立刻恢复（重装服务后才好），但**删除无用的预览域名**绝对是解决此问题的关键一步。

---

## 💡 第四部分：架构与数据避坑指南

这次迁移换来了几条血泪经验，特别是关于数据和域名的解耦：

### 1. 对象存储（R2）的域名解耦
*   **问题**：数据库中存储的图片链接使用的是业务域名（如 `api.mydomain.com/images/...`），迁移导致域名解析变动，图片无法加载。
*   **建议**：**资源域名与业务域名分离**。为 R2 对象存储绑定独立的资源域名（如 `assets.mydomain.com`），无论后端服务怎么迁，资源链接永远不变。

### 2. 域名平滑过渡
*   **问题**：直接修改 DNS 指向新 IP，导致部分 DNS 缓存未更新的用户无法访问。
*   **建议**：迁移期间采用 **新域名 + 新服务** 并行运行。待新服务稳定后，再将旧域名 CNAME 到新域名，或在低峰期切换 DNS。

---

## 🏁 最终总结：放弃“全站迁移”，拥抱“重建”

这是本次迁移最大的教训：**不要迷信 Dokploy 的“全站备份/恢复”功能。**

“一键恢复”是给同服务恢复使用的，在跨服务器、跨网络环境迁移时，往往会把旧环境的 IP 配置、缓存文件甚至错误的路由规则一并带过来。而且，全站备份往往难以保证运行中数据库的数据一致性。

**最佳实践路径应该是：**

1.  **应用层**：在新的 VPS 上**手动重新创建应用**。这虽然多花几分钟，但能保证环境是最干净的，没有任何历史包袱。
2.  **数据层**：不要依赖文件系统的 Volume 备份。进入旧 Dokploy 的 Database 页面，使用 **BackUp** 功能导出纯净的 SQL 文件。
3.  **恢复**：在新数据库中导入 SQL。

**简而言之：应用手动新建 + 数据库导入 SQL > 全站自动恢复。**
前者虽然手动步骤多，但它更干净、更可控，能让你在迁移过程中清楚地知道每一个环节的状态，避免出现“恢复成功但跑不起来”的玄学问题。