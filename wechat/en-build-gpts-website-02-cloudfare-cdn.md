---
title: Building GPTs Directory Website from 0 to 1 (Part 2): Cloudflare CDN Performance Optimization
date: 2024-03-07 20:54:28
categories: Website Building
---

Today, I'll introduce how to integrate your GPTs Directory website with Cloudflare CDN to make your website load instantly and enhance user experience.

## CDN Integration
The distance to your website varies for visitors from different countries, and farther distances mean slower access. By using a CDN, you can ensure that visitors from different countries have equally fast access to your website. As seen on Cloudflare's official website, their CDN is free to use!

![img.png](/images/build-gpts-website-02-cloudfare-cdn/img.png)

After [registering with Cloudflare](https://dash.cloudflare.com/sign-up), navigate to the main interface and click "Add a site."

![img_1.png](/images/build-gpts-website-02-cloudfare-cdn/img_1.png)

Enter your domain name and click "Continue."

![img_2.png](/images/build-gpts-website-02-cloudfare-cdn/img_2.png)

Select the Free plan and click "Continue" again.

![img_3.png](/images/build-gpts-website-02-cloudfare-cdn/img_3.png)

Continue to the third step.

![img_4.png](/images/build-gpts-website-02-cloudfare-cdn/img_4.png)

Scroll down to see two nameservers. Replace your domain's DNS nameservers with these two nameservers.

![img_5.png](/images/build-gpts-website-02-cloudfare-cdn/img_5.png)

I'll demonstrate with GoDaddy here. In the DNS management interface, under Nameservers, click "Change Nameservers," then return to Cloudflare and click "Continue" after the modification is complete.

![img_6.png](/images/build-gpts-website-02-cloudfare-cdn/img_6.png)

After a few hours for DNS resolution to take effect, your website will be successfully integrated with CDN.

## CDN Testing
Use [Check Host](https://check-host.net/check-ping) to ping. If there are more than 1 independent IPs, it means CDN integration was successful.

![img_7.png](/images/build-gpts-website-02-cloudfare-cdn/img_7.png)
![img_8.png](/images/build-gpts-website-02-cloudfare-cdn/img_8.png)

Isn't it simple, friends? Get started right away!
