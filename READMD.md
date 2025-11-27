## 初始化
```shell
# 使用 node 22
nvm use 22
npm i
cp themes/even/_config.yml.yjz themes/even/_config.yml
npm run dev
```


## NPM Scripts 说明

- **`build`**: `hexo g -w` - 生成静态文件并监听文件变化（开发用，CI/CD 不适用）
- **`build:prod`**: `hexo clean && hexo generate` - 清理并生成静态文件（适合 CI/CD 和生产环境）
- **`server`**: `hexo s` - 启动本地开发服务器
- **`clean`**: `hexo clean` - 清理生成的静态文件
- **`release`**: `hexo clean && hexo g && hexo d` - 清理、生成并部署到 Git
- **`dev`**: `npm run build & npm run server` - 开发模式，同时运行构建和服务器

## Cloudflare Pages 部署

### 配置说明

项目已配置 `wrangler.toml` 用于 Cloudflare 部署：

```toml
name = "serious-blog"
compatibility_date = "2025-11-27"

[assets]
directory = "./public"
```

### 在 Cloudflare Pages Dashboard 中配置

1. 进入 Cloudflare Dashboard → Pages → Create a project
2. 连接你的 Git 仓库
3. 配置构建设置：
   - **构建命令**: `npm run build:prod`
   - **输出目录**: `public`
   - **Node.js 版本**: 建议使用 18 或 20
4. 保存并部署

### 使用 Wrangler CLI 部署

```shell
# 先构建
npm run build:prod

# 部署到 Cloudflare Pages
npx wrangler pages deploy ./public
```

**注意**: `wrangler.toml` 主要用于 Cloudflare Workers，Cloudflare Pages 的构建配置通常在 Dashboard 中设置。`wrangler.toml` 中的 `[assets]` 配置在 Pages 中不会生效，但保留也无妨。
