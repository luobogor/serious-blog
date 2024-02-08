---
title: Cloudfare 常用安全规则配置指南
date: 2024-02-08 18:18:12
categories: 技术
---

最近使用 Cloudfare 做了一些安全配置，分享一下。

WAF 添加跳过规则，设置某些合法爬虫可以访问。

```
(cf.client.bot) or (http.user_agent contains "duckduckgo") or (http.user_agent contains "facebookexternalhit") or (http.user_agent contains "Feedfetcher-Google") or (http.user_agent contains "LinkedInBot") or (http.user_agent contains "Mediapartners-Google") or (http.user_agent contains "msnbot") or (http.user_agent contains "Slackbot") or (http.user_agent contains "TwitterBot") or (http.user_agent contains "ia_archive") or (http.user_agent contains "APIs-Google") or (http.user_agent contains "AdsBot-Google") or (http.user_agent contains "Mediapartners-Google") or (http.user_agent contains "Googlebot") or (http.user_agent contains "Mediapartners-Google") or (http.user_agent contains "FeedFetcher-Google") or (http.user_agent contains "Google-Read-Aloud") or (http.user_agent contains "DuplexWeb-Google") or (http.user_agent contains "googleweblight") or (http.user_agent contains "Storebot-Google") or (http.user_agent contains "Google-Site-Verification")
```

![](/images/cloudfare-rule/img.png)

WAF 添加托管质询规则，防止恶意访问。

```
(cf.threat_score ge 5 and not cf.client.bot) or (not http.request.version in {"HTTP/1.2" "HTTP/2" "HTTP/3" "SPDY/3.1"}) or (not http.user_agent contains "Mozilla/") 
```

![](/images/cloudfare-rule/img_1.png)

开启安全性 -> 自动程序。