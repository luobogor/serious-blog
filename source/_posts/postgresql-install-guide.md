---
title: PostgreSQL 15安装指南
date: 2024-02-17 18:18:12
categories: 技术
---

最近因工作需要安装 PostgreSQL 15，安装环境 CentOS Stream 8，下面详细讲讲如何安装。 

## 安装 PostgreSQL
安装 PostgreSQL 15 服务器：

```shell
dnf install -y postgresql15-server
```

修复「Failed to set locale, defaulting to C.UTF-8」错误：
```shell
dnf install langpacks-en glibc-all-langpacks -y
localectl set-locale LANG=en_US.UTF-8
```

初始化数据库：
```shell
/usr/pgsql-15/bin/postgresql-15-setup initdb
```

## 管理 PostgreSQL 服务
验证已安装的 PostgreSQL 版本：
```shell
psql -V
```

启动 PostgreSQL 服务：
```shell
systemctl start postgresql-15.service
```

检查 PostgreSQL 服务的状态：
```shell
systemctl status postgresql-15.service
```

## 配置 PostgreSQL
连接到本地数据库：
```shell
sudo -u postgres psql
```

修改密码：
```shell
ALTER USER postgres WITH PASSWORD '123456';

# 若提示 ALTER ROLE 则表示修改成功 
```

如果需要从远程连接，则需要修改配置文件连接到远程数据库：

```shell
sudo vim /var/lib/pgsql/15/data/pg_hba.conf
# 添加以下行
# host    all             all             0.0.0.0/0            md5

sudo vim /var/lib/pgsql/15/data/postgresql.conf
# 编辑以下行
# listen_addresses = '*'

systemctl restart postgresql-15.service
# 测试连接
psql -h <database ip> -p 5432 -U postgres -d postgres
```


## Node.js 连接 PostgreSQL
安装 pg
```shell
npm i pg
```

使用 pg 进行查询

```javascript
const { Pool } = require('pg');

// PostgreSQL数据库连接配置
const dbConfig = {
  user: 'your_username',
  host: 'localhost',
  database: 'your_database_name',
  password: 'your_password',
  port: 5432, // 默认端口为5432
};

// 创建 PostgreSQL 连接池
const pool = new Pool(dbConfig);

// 定义查询参数
const userId = 1;

// 执行参数化查询
pool.query('SELECT * FROM your_table_name WHERE user_id = $1', [userId])
  .then((result) => {
    console.log('Query result:');
    console.table(result.rows); // 打印查询结果
  })
  .catch((error) => {
    console.error('Error executing query:', error);
  })
  .finally(() => {
    // 注意：不需要手动释放连接，连接池会自动管理
    // 但是在实际生产环境中，可能需要在应用程序关闭时清理连接池
  });
```

## Python 连接 PostgreSQL
安装 psycopg2
```shell
pip3 install psycopg2
```

连接数据库

```python
import psycopg2

# 连接到 PostgreSQL 数据库
conn = psycopg2.connect(
    dbname="postgres",
    user="postgres",
    password="your password",
    host="your ip",
    port="5432"
)

# 创建一个光标对象，用于执行 SQL 查询和命令
cur = conn.cursor()

# 插入数据到表中
cur.execute("INSERT INTO my_table (url) VALUES (%s)", ('https://example.com',))


# 关闭游标和连接
cur.close()
conn.close()
```


## 参考
- [Install latest PostgreSQL 15 on Linux in best way](https://maggiminutes.com/install-postgresql-15-on-linux/)
