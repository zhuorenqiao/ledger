# ledger-front — 记账本（Flutter 客户端）

Flutter 记账应用，数据来自 Java 后端 + MySQL（同级目录 `../ledger-backend`）。
日/月/年趋势与分类占比都由后端 SQL 聚合，客户端只负责渲染。

## 跑起来

```bash
cd ../ledger-backend
docker compose up -d        # MySQL 8.4，首次启动自动建表
./mvnw spring-boot:run      # 后端，http://localhost:9090

cd -
flutter run -d web-server --web-port 8888   # 打开 http://127.0.0.1:8888
```

注册一个账号即可进入；已有数据的话用登录页里的账号密码登录。
登录页可以直接改服务器地址，Android 模拟器请用 `--dart-define=API_BASE_URL=http://10.0.2.2:9090`。
进去后用右上角菜单的「载入示例数据」灌一批账单，图表才有内容。

接口清单、环境变量与端口说明见同级目录的 `../ledger-backend/README.md`。

## 结构

- `lib/data/api_client.dart` — dio 封装，注入 Bearer token，错误统一成 `ApiException`
- `lib/data/remote_ledger_repository.dart` — 走 REST 的账本仓库（线上用的就是它）
- `lib/data/ledger_repository.dart` — 仓库接口 + 本地 SQLite / SharedPreferences 实现（离线备用，单测也用它）
- `lib/auth/auth_session.dart` — JWT 与服务器地址的持久化、注册/登录/退出、改资料
- `lib/pages/profile_page.dart` — 个人中心（右上角菜单进入）：点头像换图、改显示名称/手机号/邮箱，登录账号只读
- `lib/utils/validators.dart` — 手机号与邮箱的校验正则，和后端 DTO 上的约束一一对应
- `lib/state/ledger_store.dart` — 内存账本 + 把统计委托给仓库
- `lib/models/stats.dart` — `Summary` / `TrendPoint` 等统计模型

## 测试

```bash
flutter test                                            # 单元 + golden，全部本地仓库，不依赖后端
RUN_BACKEND_TESTS=1 flutter test test/backend_integration_test.dart   # 真实打到后端的联调用例
```
