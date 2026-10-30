# 记账本后端（Spring Boot + MySQL）

Flutter 客户端（同级目录 `../ledger-front`）的数据源。账单落 MySQL，统计口径由 SQL 聚合完成，客户端只做渲染。

> 本文只讲服务端。仓库整体结构、一键启动、架构图见上级目录的 [`../README.md`](../README.md)。

- Java 17 / Spring Boot 3.5 / Spring Security（JWT）/ Spring Data JPA
- MySQL 8.4，用 Docker Compose 启动

## 启动

```bash
# 1. 起数据库（首次启动会自动执行 db/schema.sql 建表）
docker compose up -d

# 2. 起后端
./mvnw spring-boot:run            # 或 ./mvnw -DskipTests package && java -jar target/ledger-backend-1.0.0.jar
```

后端监听 **9090**。之所以不是 8080：本机 Windows 把 TCP 8006–8105 整段保留给了
Hyper-V/WSL2，8080 绑不上会直接启动失败（`netsh interface ipv4 show excludedportrange protocol=tcp` 可复现）。
要换端口用 `SERVER_PORT=... ./mvnw spring-boot:run`。

Flutter 侧默认连 `http://localhost:9090`，可覆盖：

```bash
flutter run -d web-server --web-port 8888
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:9090   # 模拟器访问宿主机
```

登录页里也能直接改服务器地址，改完存在 SharedPreferences 中。

## 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `DB_HOST` / `DB_PORT` / `DB_NAME` | `localhost` / `3306` / `ledger` | MySQL 位置 |
| `DB_USER` / `DB_PASSWORD` | `ledger` / `ledger-dev` | 与 docker-compose.yml 对应 |
| `JWT_SECRET` | 开发用默认值 | **生产必须覆盖**，HS512 密钥，至少 32 字节 |
| `SERVER_PORT` | `9090` | HTTP 端口 |
| `AVATAR_DIR` | `data/avatars` | 头像落盘目录，相对后端启动目录；容器化时挂持久卷 |
| `FEEDBACK_DIR` | `data/feedback` | 反馈图片落盘目录 |
| `CORS_ALLOWED_ORIGIN_PATTERNS` | `http://localhost:[*],http://127.0.0.1:[*]` | 逗号分隔的允许来源；走 nginx 同源反代的预览站不触发 CORS |

## 统一响应体

所有接口（含出错时）都返回同一层包装，由 `ApiResponseBodyAdvice` 全局加上，控制器只写业务对象：

```json
{ "code": 0, "message": "成功", "success": true, "data": { ... } }
{ "code": 40401, "message": "账单 999999 不存在", "success": false, "data": null }
```

- `success`：本次请求是否成功，等价于 `code == 0`
- `code`：业务码，`0` 表示成功；失败时见下表
- `message`：可直接展示给用户的文案
- `data`：业务数据，出错时为 `null`

HTTP 状态码与 `code` 同时给出、互不替代：网关/浏览器按 HTTP 判断，客户端按 `code` 分支。
Flutter 侧 `ApiClient` 会自动剥掉这层包装，只把 `data` 交给上层，并在失败时抛出带 `code` 的 `ApiException`。

| code | HTTP | 含义 |
| --- | --- | --- |
| 0 | 200 | 成功 |
| 40000 | 400 | 请求参数不合法（校验、缺参、类型不符、JSON 解析失败） |
| 40001 | 400 | 分类不合法 |
| 40100 | 401 | 未登录或登录已过期 |
| 40101 | 401 | 用户名或密码错误 |
| 40300 | 403 | 没有权限 |
| 40400 | 404 | 接口/资源不存在 |
| 40401 | 404 | 账单不存在 |
| 40500 | 405 | 请求方法不被允许 |
| 40900 | 409 | 请求与当前资源状态冲突 |
| 40901 | 409 | 用户名已被占用 |
| 41500 | 415 | 不支持的 Content-Type |
| 50000 | 500 | 服务器内部错误（未预期异常会记 error 日志） |

定义见 `web/ErrorCode.java`，抛错一律 `throw new ApiException(ErrorCode.XXX, "文案")`。

## 接口

除 `/api/auth/register`、`/api/auth/login` 外都需要 `Authorization: Bearer <token>`。
token 有效期 7 天；过期后接口返回 401，客户端会自动清会话回到登录页。

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/register` | `{username, password, nickname?, email?, phone?}` → 201，直接返回 token |
| POST | `/api/auth/login` | `{username, password}` → `{token, tokenType, expiresAt, user}` |
| GET | `/api/auth/me` | 当前账号 |
| PUT | `/api/auth/me` | 改资料 `{nickname?, email?, phone?}` → 最新账号；`username` 是登录凭据，不在此接口范围内 |
| POST | `/api/auth/me/avatar` | `multipart/form-data`，字段名 `file`；≤2MB，仅 png/jpeg/webp/gif → 最新账号 |
| GET | `/api/auth/me/avatar` | 头像二进制，`Cache-Control: no-store`；未上传时 404 |
| GET | `/api/txns?page=0&size=20&day=` | 按 `day DESC, created_at DESC` 分页，`last=true` 表示取完；`day`（`yyyy-MM-dd`）可选，只看某一天。单页上限 1000 |
| POST | `/api/txns` | 记一笔，返回带 `id` 的账单 |
| POST | `/api/txns/batch` | 批量写入（“载入示例数据”用），单次上限 5000 |
| DELETE | `/api/txns/{id}` | 删除一笔 |
| DELETE | `/api/txns` | 清空当前账号的全部账单 |
| GET | `/api/stats/summary?from=&to=` | 区间收支合计 + 分类构成，省略区间即全历史 |
| GET | `/api/stats/daily?year=&month=` | 整月每日趋势，无记录的日期补 0 |
| GET | `/api/stats/monthly?year=` | 全年 12 个月趋势 |
| GET | `/api/stats/years` | 有账单的年份，倒序 |
| POST | `/api/feedback` | 意见反馈，`multipart/form-data`：`content`（正文，≤1000 字）+ `images`（最多 3 张图，可选，同名多份） |

账单字段：`type`（`expense`/`income`）、`category`（分类 key）、`amount`、`day`（`yyyy-MM-dd`）、
`note`、`createdAt`（epoch millis）。分类 key 由后端 `CategoryCatalog` 校验，图标和文案仍在客户端
`lib/models/txn.dart` 里，服务端只认 key。

## 表结构

`db/schema.sql`，由 MySQL 容器首次初始化时执行；应用侧是 `spring.jpa.hibernate.ddl-auto=validate`，
只校验不建表。`users` 与 `txn` 一对多，删账号时账单级联删除。

三张表：

| 表 | 内容 | 关键约束 |
| --- | --- | --- |
| `users` | 账号、昵称、邮箱、手机号、头像文件名 | `uk_users_username` 唯一索引 |
| `txn` | 账单：类型、分类 key、金额、日期、备注 | `idx_txn_user_day(user_id, day, created_at)`；外键级联 |
| `feedback` | 反馈正文与图片文件名列表 | `idx_feedback_user_created(user_id, created_at)`；外键级联 |

initdb 脚本只在数据卷为空时跑一次，所以改过 `schema.sql` 后，已有的库要手动补列，否则启动时 validate 会失败：

```bash
docker exec ledger-mysql mysql -uroot -pledger-root ledger -e "
  ALTER TABLE users ADD COLUMN email  VARCHAR(255) NOT NULL DEFAULT '' AFTER nickname,
                    ADD COLUMN phone  VARCHAR(20)  NOT NULL DEFAULT '' AFTER email,
                    ADD COLUMN avatar VARCHAR(64)  NOT NULL DEFAULT '' AFTER phone;"
```

`email` 与 `phone` 都是选填，空串即未填；只在个人中心可改，都不做唯一性约束，也不发验证短信/邮件。
手机号只认中国大陆 11 位（`1[3-9]` 开头），正则 `|1[3-9]\d{9}` 同时挂在注册和改资料两个 DTO 上，
客户端 `lib/utils/validators.dart` 里有一份等价的，改规则要两边一起改。

头像图片落在 `app.storage.avatar-dir`（默认 `data/avatars/`，已 gitignore），数据库只记文件名
`{userId}.{扩展名}`。文件名由服务端按 Content-Type 生成，客户端传的文件名一律不用，所以不存在
路径穿越；换图时删掉旧文件。地址固定为 `/api/auth/me/avatar` 且响应 `no-store`；客户端会额外带一个
`?v=` 查询参数用于绕开自己进程内的图片缓存，服务端忽略它。

## 反馈与素材上传

头像和反馈图片共用同一套做法：**图片落盘，数据库只记文件名**。

- 扩展名由服务端按 `Content-Type` 反推，客户端传的文件名一律不用，因此不存在路径穿越
- 头像：`data/avatars/{userId}.{ext}`，换图时删掉旧文件
- 反馈图片：`data/feedback/{userId}-{uuid}.{ext}`
- 限额：单文件 ≤2MB、整包 ≤10MB（`spring.servlet.multipart`），超出直接 413
- 反馈正文 ≤1000 字（按码点计，与 `VARCHAR(1000)` 的字符计数一致）、图片 ≤3 张

反馈接口是 `multipart/form-data`：`content` 是正文文本域，`images` 是可选的同名多份文件。
客户端 `lib/data/feedback_repository.dart` 的上限与服务端常量对齐，前端先拦一次，省掉必然失败的请求。

`FeedbackService` 会先把所有扩展名校验完再落盘，避免中途失败留下一堆没用的文件；写盘成功后再落库。
事务回滚不会顺手删掉已落盘的图片，最坏留一张孤儿图 —— 这是刻意的取舍：宁可留孤儿图，
也不要留下指向空文件的记录。

## 内网预览站

`deploy/docker-compose.preview.yml` 起一个 nginx 容器，把 Flutter Web 产物和后端 API 拼成**同一个站点**：

```bash
cd ../ledger-front && flutter build web --release --no-web-resources-cdn && cd -
docker compose -f deploy/docker-compose.preview.yml up -d
```

访问 `http://<本机内网IP>:8889`。浏览器与 API 同源，不会触发 CORS 预检；`/api` 由 nginx 反代到
宿主机的 `host.docker.internal:9090`。停掉用 `docker compose -f deploy/docker-compose.preview.yml down`。

两个容易踩的点：

- Web 产物**必须**带 `--no-web-resources-cdn`。默认产物是从 `https://www.gstatic.com/flutter-canvaskit/`
  拉 CanvasKit 的，内网或被 TLS 拦截的网络上拉不到就是白屏。
- nginx 把 `proxy_read_timeout` 提到 120s，因为批量灌示例数据（单次 5000 条）会比较慢，
  默认 60s 会把它掐断。

## 快速自测

```bash
curl -X POST http://localhost:9090/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo_user","password":"secret123","nickname":"demo"}'

# 带上 token 后
curl "http://localhost:9090/api/stats/summary?from=2026-09-01&to=2026-09-30" \
  -H "Authorization: Bearer $TOKEN"

# 提一条反馈（content 是文本域，images 可选，最多 3 张）
curl -X POST http://localhost:9090/api/feedback \
  -H "Authorization: Bearer $TOKEN" \
  -F "content=字体在离线环境也能正常显示了" \
  -F "images=@shot1.png" -F "images=@shot2.png"
```

客户端契约的真实联调（需后端在跑）：

```bash
cd ../ledger-front && RUN_BACKEND_TESTS=1 flutter test test/backend_integration_test.dart
```
