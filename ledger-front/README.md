# ledger-front — 记账本（Flutter 客户端）

Flutter 记账应用，数据来自 Java 后端 + MySQL（同级目录 `../ledger-backend`）。
日/月/年趋势与分类占比都由后端 SQL 聚合，客户端只负责渲染。

> 本文只讲客户端。仓库整体结构、一键启动、架构图见上级目录的 [`../README.md`](../README.md)。

## 跑起来

仓库根目录有一键脚本（MySQL → 后端 → 前端全拉起）：

```powershell
..\dev.ps1
```

也可以分步手起：

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

**页面**（`lib/pages/`）

- `login_page.dart` — 注册 / 登录，可现场改后端地址
- `home_page.dart` — 框架页：底部切换流水与报表，右上角菜单进个人中心、意见反馈、载入示例数据、退出
- `records_page.dart` — 流水列表，按天分组，滚动懒加载
- `analytics_page.dart` — 报表页：日 / 月 / 年三个视角
- `add_txn_page.dart` — 记一笔
- `profile_page.dart` — 个人中心：点头像换图、改显示名称 / 手机号 / 邮箱，登录账号只读
- `feedback_page.dart` — 意见反馈：正文 + 最多 3 张图

**状态**（`lib/state/`）

- `ledger_store.dart` — 内存账本；把统计委托给仓库，写入后 `revision++` 供报表页判断是否重拉
- `theme_mode_controller.dart` / `locale_controller.dart` — 主题模式与语言，含持久化

**会话**（`lib/auth/`）

- `auth_session.dart` — JWT 与服务器地址的持久化、注册 / 登录 / 退出、改资料、换头像；
  收到 401 时清会话，UI 自动退回登录页

**数据**（`lib/data/`）

- `api_client.dart` — dio 封装，注入 Bearer token，剥掉统一响应体只取 `data`，错误统一成 `ApiException`
- `ledger_repository.dart` — 仓库接口 + 本地 SQLite / SharedPreferences 实现（离线备用，单测也用它）
- `remote_ledger_repository.dart` — 走 REST 的账本仓库（线上用的就是它）
- `feedback_repository.dart` — 提交意见反馈，上限与服务端常量对齐，前端先拦一次
- `demo_data.dart` — 「载入示例数据」的近 14 个月演示账单

**其他**

- `lib/models/txn.dart`、`lib/models/stats.dart` — `Txn`、`Summary`、`TrendPoint` 等模型；分类 key 与文案
- `lib/widgets/charts.dart` — 图表组件（fl_chart）
- `lib/utils/validators.dart` — 手机号与邮箱的校验正则，和后端 DTO 上的约束一一对应
- `lib/utils/run_guarded.dart` — 统一的异步异常兜底
- `lib/l10n/app_localizations.dart` — 中英文文案
- `lib/app_theme.dart` — 主题与字体

## 中文字体

字体**随包自带**：`assets/fonts/NotoSansSC-Variable.ttf`（OFL 许可，许可证同目录）。

不自带的话，Web 端会依赖引擎运行时去 `fonts.gstatic.com` 拉分片字体 —— 桌面能连到 Google
不代表手机的内网/流量环境也能，连不上时中文就没有字形可画，直接渲染成一排豆腐块（□）。

`app_theme.dart` 里设了全局 `fontFamily`，同时提供 `withAppFont()` 给组件主题里手写了 `TextStyle`
的地方补字体族。注意 `DefaultTextStyle` 是**替换**外层默认样式而不是合并（只有 `DefaultTextStyle.merge`
才合并），组件主题里漏写 `fontFamily` 字族就会被整个丢掉。

## 测试

```bash
flutter test                                            # 单元 + golden，全部本地仓库，不依赖后端
RUN_BACKEND_TESTS=1 flutter test test/backend_integration_test.dart   # 真实打到后端的联调用例
```

> 当前有 8 个 golden 测试失配：内置字体那次改动改了全局 `fontFamily`，但 `test/goldens/` 的基准图
> 没有跟着重新生成。需要时执行 `flutter test --update-goldens` 重新生成。
>
> 另外 `test/failures/` 是测试失败时的 diff 图，历史上被误提交进了仓库，跑一次测试就会弄脏工作区，
> 建议加进 `.gitignore` 并 `git rm -r --cached` 掉。
