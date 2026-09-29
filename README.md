# 记账本后端（Spring Boot + MySQL）

Flutter 客户端（同级目录 `../ledger-front`）的数据源。账单落 MySQL，统计口径由 SQL 聚合完成，客户端只做渲染。

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
| POST | `/api/auth/register` | `{username, password, nickname?}` → 201，直接返回 token |
| POST | `/api/auth/login` | `{username, password}` → `{token, tokenType, expiresAt, user}` |
| GET | `/api/auth/me` | 当前账号 |
| GET | `/api/txns?page=0&size=20&day=` | 按 `day DESC, created_at DESC` 分页，`last=true` 表示取完；`day`（`yyyy-MM-dd`）可选，只看某一天。单页上限 1000 |
| POST | `/api/txns` | 记一笔，返回带 `id` 的账单 |
| POST | `/api/txns/batch` | 批量写入（“载入示例数据”用），单次上限 5000 |
| DELETE | `/api/txns/{id}` | 删除一笔 |
| DELETE | `/api/txns` | 清空当前账号的全部账单 |
| GET | `/api/stats/summary?from=&to=` | 区间收支合计 + 分类构成，省略区间即全历史 |
| GET | `/api/stats/daily?year=&month=` | 整月每日趋势，无记录的日期补 0 |
| GET | `/api/stats/monthly?year=` | 全年 12 个月趋势 |
| GET | `/api/stats/years` | 有账单的年份，倒序 |

账单字段：`type`（`expense`/`income`）、`category`（分类 key）、`amount`、`day`（`yyyy-MM-dd`）、
`note`、`createdAt`（epoch millis）。分类 key 由后端 `CategoryCatalog` 校验，图标和文案仍在客户端
`lib/models/txn.dart` 里，服务端只认 key。

## 表结构

`db/schema.sql`，由 MySQL 容器首次初始化时执行；应用侧是 `spring.jpa.hibernate.ddl-auto=validate`，
只校验不建表。`users` 与 `txn` 一对多，删账号时账单级联删除。

## 快速自测

```bash
curl -X POST http://localhost:9090/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo_user","password":"secret123","nickname":"demo"}'

# 带上 token 后
curl "http://localhost:9090/api/stats/summary?from=2026-09-01&to=2026-09-30" \
  -H "Authorization: Bearer $TOKEN"
```

客户端契约的真实联调（需后端在跑）：

```bash
cd ../ledger-front && RUN_BACKEND_TESTS=1 flutter test test/backend_integration_test.dart
```
