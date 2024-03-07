# Building GPTs Directory Website from 0 to 1 (Part 1): How to Collect GPTs

![Guangzhou Haizhu Wetland Park](/images/build-gpts-website-01-gpts-scraping/cover.jpg)

## Preface
As a novice in website creation, three months ago, I launched a GPTs directory website - [GPTs Happy](https://gptshappy.tools?utm_source=medium). This series of articles mainly summarize what I have done in the past three months and introduce how to build a website from 0 to 1.

In summary, in the past three months, I have mainly done the following:

1. Learned web scraping and collected 37,000 GPTs.
2. Improved website access speed using methods like Cloudflare CDN.
3. Optimized SEO using various strategies.
4. Integrated tools such as Google Search Console, GA4, Clarity Microsoft, etc., to track website traffic.
5. Promoted the website on platforms like V2EX, Product Hunt, Reddit, X, etc.

The website operation is as follows:
- Indexed by Google with 27,000 results.
  ![google-result.png](/images/build-gpts-website-01-gpts-scraping/img1.png)

- Traffic, with over 100 visitors.
  ![google-analytics.png](/images/build-gpts-website-01-gpts-scraping/img2.png)

Today, I mainly want to share with you a concern for many people, how to build a website and index GPTs. I'll share the problems I encountered in this process and how I solved them. This will be easier for technical personnel to understand, but non-technical individuals can also take it as a reference.

## Project Setup
Simply use [gpts.works](https://github.com/all-in-aigc/gpts-works), deploy it to Vercel according to the documentation, and you're good to go, super convenient.

## Scraping Twitter GPTs Search Results
Although I'm a developer, I haven't done web scraping before. At that time, I was also thinking about how to index and how to find the fundamental source of the data and then scrape it. I found out that the initial data source for [GPTs Works](https://gpts.works?utm_source=luobogor.gitee.io) shared by [GPTs hunter](https://www.gptshunter.com?utm_source=luobogor.gitee.io). So I followed the trail and found some [shares](https://v2ex.com/t/990120) from the author of GPTs hunter:

![v2ex.png](/images/build-gpts-website-01-gpts-scraping/img3.png)

Following the author's approach, I wrote two scraping scripts that you can directly use:

1. [Scrape GPTs links from Twitter](https://github.com/luobogor/twitter-gpts-crawler)
2. [Scrape GPTs details from ChatGPT](https://github.com/luobogor/gpts-detail-crawler)

## Scraping Google GPTs Search Results
Of course, many people mentioned online that you can search on Google using `site:chat.openai.com/g/` to filter out GPTs links.

![google-result2.png](/images/build-gpts-website-01-gpts-scraping/img4.png)

After researching Google search, if you write a script to request pagination, you can do it like this: `https://google.com/search?q=Query&num=10&start=0`. But there are two problems: first, if the rate is too fast, you will be prompted for a CAPTCHA, so don't request too quickly. Another issue is that although Google tells you it has indexed 490,000 records, in reality, you can only browse the first 10 pages or so. Further scrolling will reveal the end, and you won't be able to scroll further. Using the API will have the same problem. To this day, this problem has not been solved.
