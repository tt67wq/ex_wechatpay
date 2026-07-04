# 虚拟支付实现计划

## 依赖顺序

```
Phase 1: Config Schema
    ↓
Phase 2: Signature 模块（无外部依赖，可独立测试）
    ↓
Phase 3: Client 模块（依赖 Config + Signature + Finch）
    ↓
Phase 4: Callback 模块（无外部依赖）
    ↓
Phase 5: 主入口集成（依赖 Phase 2-4）
    ↓
Phase 6: 测试 + 文档
```

---

## Phase 1: Config Schema

**文件**：`lib/ex_wechatpay/config/schema.ex`（修改）

**任务**：
1. 在现有 Schema 中新增 `:virtual_pay` 可选字段
2. 定义 virtual_pay 子 schema：
   - `offer_id` (string, required)
   - `app_key` (string, required)
   - `app_key_sandbox` (string, optional)
   - `env` (integer, default: 1)
3. 验证函数：env ∈ {0, 1}

**验证**：`mix test` 现有测试不挂；新字段可选，不影响现有配置。

---

## Phase 2: Signature 模块

**文件**：`lib/ex_wechatpay/virtual_pay/signature.ex`（新建）

**任务**：
1. `pay_sig(app_key, path, body)` — 服务端 API 签名
2. `client_pay_sig(app_key, sign_data_str)` — 客户端签名（自动加 `requestVirtualPayment&` 前缀）
3. `user_signature(session_key, sign_data_str)` — 用户态签名
4. 内部 `hmac_sha256(key, message)` 私有函数

**验证**：
- 单元测试：已知 key + message → 已知 hex 输出
- 边界：空字符串、特殊字符

---

## Phase 3: Client 模块

**文件**：
- `lib/ex_wechatpay/virtual_pay/client.ex`（新建）
- `lib/ex_wechatpay/virtual_pay/token_agent.ex`（新建）

### 3a: TokenAgent

**任务**：
1. `start_link/1` — 启动 Agent，初始状态 `%{token: nil, expires_at: 0}`
2. `get_token/1` — 获取 token，过期前 300s 自动刷新
3. `refresh_token/2` — 调微信 `cgi-bin/token` 接口获取新 token
4. 原子操作避免并发刷新（`Agent.update` + compare-and-swap）

**验证**：单元测试 mock HTTP 响应，测试过期刷新。

### 3b: Client

**任务**：
1. `query_balance/3` — 查余额
2. `query_order/3` — 查订单
3. `refund/4` — 退款
4. `notify_deliver/3` — 通知发货
5. `code2session/3` — 换 session_key + openid
6. 内部 `do_xpay_request/4` — 统一 xpay 请求（组装 URL + pay_sig + body）

**验证**：mock HTTP 响应，测试 URL 拼接、签名头、错误处理。

---

## Phase 4: Callback 模块

**文件**：`lib/ex_wechatpay/virtual_pay/callback.ex`（新建）

**任务**：
1. `parse_deliver/1` — 解析发货回调 JSON，容错字段名
2. `parse_refund/1` — 解析退款回调 JSON，容错字段名
3. `success_response/0` — 返回 `%{"ErrCode" => 0, "ErrMsg" => "success"}`
4. 内部 `normalize_keys/1` — 大小写容错映射

**验证**：单元测试覆盖大写/小写/混合字段名。

---

## Phase 5: 主入口集成

**文件**：
- `lib/ex_wechatpay/virtual_pay.ex`（新建）— 组合函数
- `lib/ex_wechatpay.ex`（修改）— 宏注入虚拟支付函数
- `lib/ex_wechatpay/supervisor.ex`（修改）— 启动 TokenAgent

### 5a: VirtualPay 组合模块

**任务**：
1. `sign/2` — 组装 signData + 计算所有签名 → `%{sign_data, sign_data_str, pay_sig, signature}`
2. 内部 `build_sign_data/3` — 组装 signData map + JSON 序列化
3. 内部 `select_app_key/2` — 按 env 选 app_key / app_key_sandbox

### 5b: 宏注入

**任务**：
1. 在 `__using__` 宏中添加 `delegate` 到 VirtualPay
2. 函数名：`virtual_pay_sign/1`, `virtual_pay_query_balance/2`, 等
3. 遵循现有 delegate 模式（`defp delegate` → `apply(Core, ...)` 改为也支持 VirtualPay）

### 5c: Supervisor

**任务**：
1. 在 `Supervisor.init/2` 中添加 `TokenAgent` child spec
2. 每个商户配置启动独立 TokenAgent
3. TokenAgent 通过 config 获取 appid/secret

**验证**：`mix compile` 无警告；`iex -S mix` 能启动 supervisor。

---

## Phase 6: 测试 + 文档

**文件**：
- `test/ex_wechatpay/virtual_pay/signature_test.exs`
- `test/ex_wechatpay/virtual_pay/client_test.exs`
- `test/ex_wechatpay/virtual_pay/callback_test.exs`
- `test/ex_wechatpay/virtual_pay_test.exs`

**任务**：
1. 签名算法确定性测试（已知输入 → 已知输出）
2. Client mock 测试（bypass / mock HTTP）
3. Callback 容错测试
4. 集成测试：完整 sign → mock xpay → 验证流程
5. 更新 README 添加虚拟支付用法
6. 更新 `docs/advanced_usage.md`

**验证**：`mix test` 全绿；`mix credo` 无新增 warning；`mix dialyzer` 通过。

---

## 文件清单

| 文件 | 操作 | Phase |
|------|------|-------|
| `lib/ex_wechatpay/config/schema.ex` | 修改 | 1 |
| `lib/ex_wechatpay/virtual_pay/signature.ex` | 新建 | 2 |
| `lib/ex_wechatpay/virtual_pay/token_agent.ex` | 新建 | 3a |
| `lib/ex_wechatpay/virtual_pay/client.ex` | 新建 | 3b |
| `lib/ex_wechatpay/virtual_pay/callback.ex` | 新建 | 4 |
| `lib/ex_wechatpay/virtual_pay.ex` | 新建 | 5a |
| `lib/ex_wechatpay.ex` | 修改 | 5b |
| `lib/ex_wechatpay/supervisor.ex` | 修改 | 5c |
| `test/ex_wechatpay/virtual_pay/*` | 新建 | 6 |
| `README.md` | 修改 | 6 |

## 里程碑

| 里程碑 | 包含 Phase | 可验证产出 |
|--------|-----------|-----------|
| M1: 签名可用 | 1-2 | `Signature` 模块通过单元测试 |
| M2: API 可调 | 3 | `Client` 能成功调 xpay（mock） |
| M3: 回调可解析 | 4 | `Callback` 解析通过测试 |
| M4: 集成完成 | 5 | `MyApp.WechatPay.virtual_pay_sign/1` 可用 |
| M5: 发布就绪 | 6 | 全测试通过 + 文档更新 |
