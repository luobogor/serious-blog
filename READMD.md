## 初始化
```shell
# 使用 node 14
nvm use 14
npm i
cp themes/even/_config.yml.yjz themes/even/_config.yml
npm run dev
```

## 部署
初次部署
```shell
npm run release
cd ./.deploy_git
git remote add origin git@gitee.com:luobogor/luobogor.git
git checkout master
git push origin master --force
```

二次部署
```shell
make pub
```

推送代码后进入 [gitee pages](https://gitee.com/luobogor/luobogor/pages) ，点击「更新」即可完成部署
