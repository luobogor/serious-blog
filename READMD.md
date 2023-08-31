## 初始化
```shell
npm i
cp themes/even/_config.yml.yjz themes/even/_config.yml
```

## 部署
```shell
npm run release
cd ./.deploy_git
git remote add origin git@gitee.com:yejinzhan/yejinzhan.git
git checkout master
git push origin master --force
```

推送代码后进入 [gitee pages](https://gitee.com/yejinzhan/yejinzhan/pages) ，点击「更新」即可完成部署
