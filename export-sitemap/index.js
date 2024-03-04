const fs = require('fs');
const path = require('path');

// 要遍历的目录数组
const dirs = [
  '2018',
  '2019',
  '2020',
  '2021',
  '2022',
  '2023',
  '2024',
  'about',
  'categories',
].map((item) => {
  return path.resolve(__dirname, `../public/${ item }`)
});

// 保存所有 index.html 文件路径的数组
const files = [];

// 递归遍历目录数组
function walkDirs(dirs) {
  // 遍历目录数组
  dirs.forEach(dir => {
    // 递归遍历目录
    walkDir(dir);
  });
}

// 递归遍历目录
function walkDir(dir) {
  // 读取目录下的所有文件和文件夹
  fs.readdirSync(dir).forEach(file => {
    const filePath = path.join(dir, file);
    // 判断是否是文件
    if (fs.lstatSync(filePath).isFile()) {
      // 判断文件名是否为 index.html
      if (file === 'index.html') {
        // 将文件路径添加到数组中
        files.push(`https://luobogor.gitee.io${ filePath.split('public')[1] }`);
      }
    } else {
      // 如果是文件夹，则递归遍历该文件夹
      walkDir(filePath);
    }
  });
}


async function main() {

  // 开始递归遍历
  walkDirs(dirs);

  console.log(files)

  const urlStr = files.map((item) => {
    return `<url>
        <loc>${ item }</loc>
    </url>`
  })

  const content = `<?xml version="1.0" encoding="UTF-8"?>
   <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
     ${ urlStr.join('\n') }
   </urlset>`

  // TODO 中文目录encode
  fs.writeFile(path.resolve(__dirname, './sitemap_a1.xml'), content, (err) => {
    if (err) {
      console.error('写入文件时发生错误:', err);
      return;
    }
    console.log('文件写入成功。');
  });
}

main()