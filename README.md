# 记账本 Ledger

Flutter 多端客户端 + Spring Boot 服务端 + MySQL 的记账应用。

核心设计：**统计口径全部由 MySQL 的 `GROUP BY` 聚合完成，客户端只做渲染**，因此不存在"前后端各算一套、
算法对不上"的问题。所有接口共用统一响应体与 JWT 鉴权。

```
用户 ──HTTP/JSON──▶ Spring Boot ──JDBC──▶ MySQL 8.4
                      │                    账单 / 账号 / 反馈
                      └──本地磁盘──────▶ 头像与反馈图片（库里只存文件名）
```

---

## 仓库结构

单仓（monorepo），前后端同仓、同版本、同一次提交：

```
ledger/
├── ledger-backend/       Spring Boot 服务端 —— 接口契约、数据表结构都写在这里
│   ├── src/main/java/com/example/ledger/
│   │   ├── web/          控制器、统一响应体、错误码
│   │   ├── security/     JWT 签发与校验过滤器
│   │   ├── service/      业务逻辑
│   │   ├── repository/   Spring Data JPA 与聚合查询
│   │   ├── domain/       User / Txn / Feedback
│   │   └── dto/          请求与响应对象
│   ├── db/schema.sql     建表脚本（MySQL 容器首次启动时执行）
│   ├── deploy/           nginx 同源反代的内网预览站编排
│   └── docker-compose.yml
├── ledger-front/         Flutter 客户端
│   ├── lib/pages/        登录 / 首页 / 流水 / 报表 / 记一笔 / 个人中心 / 反馈
│   ├── lib/state/        LedgerStore（账本内存态）、AuthSession、主题与语言
│   ├── lib/data/         ApiClient、仓库实现、请求模型
│   ├── lib/models/       Txn / Summary / TrendPoint
│   └── assets/fonts/     自带的 Noto Sans SC（不依赖公网字体）
├── docs/                 架构与流程图
├── dev.ps1 / dev.cmd     一键拉起全栈
└── .dev/                 运行时状态（PID 记录，不入库）
```

---

## 技术栈

| 层 | 选型 |
| --- | --- |
| 客户端 | Flutter 3.47 / Dart 3.13 · dio · fl_chart · sqflite · shared_preferences · file_picker |
| 服务端 | Java 17 · Spring Boot 3.5.16 · Spring Security（JWT）· Spring Data JPA · jjwt |
| 存储 | MySQL 8.4（Docker）· 本地磁盘存头像与反馈图片 |
| 部署 | nginx:alpine 同源托管静态产物 + `/api` 反代 |

---

## 快速开始

前置：Docker Desktop、Flutter 3.47+、JDK 17。

一键拉起（MySQL → 后端 9090 → 前端 8888，并自动开浏览器）：

```powershell
.\dev.ps1
```

注册一个账号即可进入。进去后用右上角菜单的「载入示例数据」灌一批账单，图表才有内容。

常用变体：

```powershell
.\dev.ps1 -Target android     # 连真机/模拟器，自动带上 10.0.2.2
.\dev.ps1 -BackendPort 9091   # 9090 被占时换端口（前端地址会跟着变）
.\dev.ps1 -SkipDb             # 本机已有 MySQL，跳过 docker
.\dev.ps1 -DryRun             # 只检查前置条件并打印将要执行的命令，不真起
.\dev.ps1 -Stop               # 收摊（默认不动 MySQL 容器，加 -WithDb 才一起停）
```

> 后端用 **9090 而不是 8080**：本机 Windows 把 TCP 8006–8105 整段保留给了 Hyper-V/WSL2，
> 8080 绑不上会直接启动失败。换端口用 `-BackendPort`。

也可以分步手起：

```bash
cd ledger-backend
docker compose up -d        # MySQL 8.4，首次启动自动建表
./mvnw spring-boot:run      # 后端，http://localhost:9090

cd ../ledger-front
flutter run -d web-server --web-port 8888
```

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/ledger-architecture.html](docs/ledger-architecture.html) | 整体分层、核心模块、外部依赖、四条关键链路的数据流 —— 用浏览器打开 |
| [ledger-backend/README.md](ledger-backend/README.md) | 接口清单、统一响应体与错误码、环境变量、表结构 |
| [ledger-front/README.md](ledger-front/README.md) | 客户端目录职责与测试方式 |

---

## 测试

```bash
cd ledger-front
flutter test                                             # 单元 + golden，不依赖后端
RUN_BACKEND_TESTS=1 flutter test test/backend_integration_test.dart   # 真实打到后端的联调

cd ../ledger-backend
./mvnw test
```

---

## 已知问题

- **前端 8 个 golden 测试当前失配。** 内置中文字体那次改动把全局 `fontFamily` 换成了自带的
  NotoSansSC，但 `ledger-front/test/goldens/` 的基准图没有跟着重新生成，比对时报
  `Pixel test failed`。需要时在 `ledger-front` 下执行 `flutter test --update-goldens` 重新生成。
- **`ledger-front/test/failures/` 历史上被误提交进仓库。** 那是测试失败时的 diff 图，
  任何人跑一次测试都会把工作区弄脏。建议加进 `.gitignore` 并 `git rm -r --cached` 掉。
- **`ledger-front/assets/fonts/NotoSansSC-Variable.ttf` 有 17MB。** 它是 Web 端不依赖公网字体的关键，
  但每次字体更新都是一个新的大 blob；这块若还要反复调整，值得上 Git LFS。
- **`JWT_SECRET` 仓库里带的是开发默认值**，上线前必须用环境变量覆盖（HS512，至少 32 字节）。
