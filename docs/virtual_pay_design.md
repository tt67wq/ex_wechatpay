# 虚拟支付模块设计文档

## 1. 目标

为 ex_wechatpay SDK 新增微信虚拟支付（`wx.requestVirtualPayment`）支持。

**范围**：纯 API 封装 — SDK 只负责 xpay 接口调用、签名计算、回调解析。业务逻辑（VIP 开通、订单轮询、商品映射）由应用层实现。

**不在范围内**：
- 发货/VIP 开通逻辑
- 订单轮询补偿机制
- product_id → 业务类型映射
- Web 框架集成（Plug/Phoenix controller）

## 2. 背景

微信虚拟支付用于小程序内购买虚拟商品（会员、道具等），走 `api.weixin.qq.com/xpay/*` 接口，与现有 v3 支付（`api.mch.weixin.qq.com/v3/*`）是完全不同的 API 体系：

| 维度 | v3 支付 | 虚拟支付 (xpay) |
|------|---------|-----------------|
| Base URL | api.mch.weixin.qq.com | api.weixin.qq.com |
| 签名算法 | RSA-SHA256 | HMAC-SHA256 |
| 认证方式 | 证书 + bearer token | access_token + pay_sig |
| 密钥 | client_key (PEM) + apiv3_key | app_key (字符串) |
| 前端接口 | wx.requestPayment | wx.requestVirtualPayment |

签名体系不兼容 → 不能复用现有 RequestBuilder/ResponseHandler 管道。

## 3. 架构决策

### 3.1 独立子模块

**决策**：新建 `ExWechatpay.VirtualPay` 子树，有自己的请求/响应管道，复用 Finch HTTP 层和 Supervisor 监督树。

**理由**：
- HMAC-SHA256 签名与 RSA-SHA256 完全不同，强行统一会增加复杂度
- 独立子模块互不干扰，可独立测试
- 共享 Finch 实例避免连接池浪费

```
ExWechatpay (existing)
├── Core (v3 RSA-SHA256 pipeline)
├── Service.Transaction
├── Service.Refund
└── VirtualPay (new)
    ├── Client        # xpay API 调用 + access_token 缓存
    ├── Signature     # HMAC-SHA256 签名工具
    ├── Callback      # 回调解析 + 响应格式化
    └── Config        # virtual_pay 子键 schema
```

### 3.2 Config 模型

**决策**：共享 appid/secret + 虚拟支付专属字段放 `:virtual_pay` 子键。

```elixir
config :my_app, MyApp.WechatPay,
  appid: "wx...",
  secret: "...",          # 与虚拟支付共享
  # ... 现有 v3 配置 ...
  virtual_pay: %{
    offer_id: "1450549278",
    app_key: "AHb5jYjw...",           # 现网
    app_key_sandbox: "sfbWk0xe...",   # 沙箱
    env: 1                             # 1=沙箱, 0=正式
  }
```

**理由**：
- appid/secret 是小程序级别，code2session 和 access_token 都用到，不应重复配置
- offer_id/app_key/env 是虚拟支付专属，放子键隔离

### 3.3 access_token 缓存

**决策**：SDK 内部 Agent 缓存 access_token，过期前自动刷新。

- access_token 有效期 7200s
- Agent 存储 `{token, expires_at}`
- 每次请求前检查：过期前 300s 内自动刷新
- 多商户场景：每个商户独立 Agent

### 3.4 多商户

**决策**：支持多商户，复用 `config_key` 模式。

```elixir
defmodule MerchantA do
  use ExWechatpay, otp_app: :my_app, config_key: :merchant_a
end

# 虚拟支付调用
MerchantA.VirtualPay.query_balance(openid, user_ip)
```

## 4. Public API

### 4.1 主入口模块

通过 `use ExWechatpay` 宏自动注入虚拟支付函数到用户模块：

```elixir
defmodule MyApp.WechatPay do
  use ExWechatpay, otp_app: :my_app
end

# 虚拟支付 API
MyApp.WechatPay.virtual_pay_sign(args)
MyApp.WechatPay.virtual_pay_query_balance(openid, user_ip)
MyApp.WechatPay.virtual_pay_query_order(openid, out_trade_no)
MyApp.WechatPay.virtual_pay_refund(openid, out_trade_no, refund_fee)
MyApp.WechatPay.virtual_pay_notify_deliver(openid, out_trade_no)
MyApp.WechatPay.virtual_pay_code2session(code)
```

### 4.2 签名工具

```elixir
# 服务端 API 签名（调 xpay 接口用）
ExWechatpay.VirtualPay.Signature.pay_sig(app_key, path, body)
# → "a1b2c3..." (hex lowercase)

# 客户端签名（返回给前端 wx.requestVirtualPayment）
ExWechatpay.VirtualPay.Signature.client_pay_sig(app_key, sign_data_str)
# → "d4e5f6..." (hex lowercase)
# 内部自动加 "requestVirtualPayment&" 前缀

# 用户态签名（用 session_key 算）
ExWechatpay.VirtualPay.Signature.user_signature(session_key, sign_data_str)
# → "g7h8i9..." (hex lowercase)
```

### 4.3 签名生成（组合函数）

```elixir
# 一步完成：组装 signData + 计算所有签名
ExWechatpay.VirtualPay.sign(config, %{
  product_id: "vip_six_week",
  out_trade_no: "VP...",
  code: "0a1b2c...",
  goods_price: 3000
})

# 返回：
%{
  sign_data: %{offerId: "...", buyQuantity: 1, env: 1, ...},
  sign_data_str: "{\"offerId\":\"...\",...}",  # 字节级精确 JSON
  pay_sig: "...",      # 客户端 paySig
  signature: "..."     # 用户态 signature
}
```

**关键约束**：`sign_data_str` 是 SDK 内部序列化的 JSON 字符串，前端必须原样传给 `wx.requestVirtualPayment`，不能再 `JSON.stringify`。

### 4.4 xpay 接口

```elixir
# 查余额
MyApp.WechatPay.virtual_pay_query_balance(openid, user_ip)
# → {:ok, %{"balance" => 100, ...}}

# 查订单状态
MyApp.WechatPay.virtual_pay_query_order(openid, out_trade_no)
# → {:ok, %{"order_status" => 1, ...}}

# 退款
MyApp.WechatPay.virtual_pay_refund(openid, out_trade_no, refund_fee)
# → {:ok, %{"refund_fee" => 3000, ...}}

# 通知发货
MyApp.WechatPay.virtual_pay_notify_deliver(openid, out_trade_no)
# → {:ok, %{}}
```

### 4.5 code2session

```elixir
MyApp.WechatPay.virtual_pay_code2session(code)
# → {:ok, %{session_key: "...", openid: "..."}}
```

### 4.6 回调工具

```elixir
# 解析发货回调
ExWechatpay.VirtualPay.Callback.parse_deliver(body_or_params)
# → {:ok, %{openid: "...", out_trade_no: "...", product_id: "..."}}

# 解析退款回调
ExWechatpay.VirtualPay.Callback.parse_refund(body_or_params)
# → {:ok, %{openid: "...", wx_refund_id: "...", refund_fee: 3000, ret_code: 0}}

# 成功响应
ExWechatpay.VirtualPay.Callback.success_response()
# → %{"ErrCode" => 0, "ErrMsg" => "success"}
```

回调解析支持容错字段名（`OutTradeNo` / `out_trade_no`），因为微信不同版本大小写可能不同。

## 5. 签名算法细节

所有签名均为 HMAC-SHA256，输出 hex 小写：

```elixir
:crypto.mac(:hmac, :sha256, key, message) |> Base.encode16(case: :lower)
```

### 5.1 pay_sig（服务端 API 签名）

```
key     = app_key
message = "/xpay/{path}" + "&" + post_body
```

### 5.2 client_pay_sig（客户端签名）

```
key     = app_key
message = "requestVirtualPayment&" + sign_data_str
```

⚠️ 前缀 `requestVirtualPayment&` 不可省略，否则返回 `PAY_SIG_INVALID (-15006)`。

### 5.3 user_signature（用户态签名）

```
key     = session_key（每次 code2session 获取）
message = sign_data_str
```

## 6. signData 结构

SDK 内部组装，字段顺序固定：

```json
{
  "offerId": "1450549278",
  "buyQuantity": 1,
  "env": 1,
  "currencyType": "CNY",
  "productId": "vip_six_week",
  "goodsPrice": 3000,
  "outTradeNo": "VP...",
  "attach": "hope_virtual_pay",
  "mode": "short_series_goods"
}
```

使用 `Jason.encode!/1` 序列化（Elixir map → JSON，key 按字母序排列）。

⚠️ **字节级一致性**：`sign_data_str` 必须与前端传给微信的 `signData` 完全一致。SDK 返回此字符串，前端原样使用。

## 7. 错误处理

复用现有 `ExWechatpay.Exception` 结构：

```elixir
{:error, %ExWechatpay.Exception{type: :xpay_error, code: -15006, message: "PAY_SIG_INVALID"}}
```

xpay 接口错误码直接透传微信返回值。

## 8. 测试策略

- 签名算法：已知输入 → 已知输出，确定性测试
- xpay 接口：mock HTTP 响应（复用现有 test helper）
- access_token 缓存：测试过期刷新逻辑
- 回调解析：测试大小写容错
- code2session：mock HTTP 响应

## 9. 风险与缓解

| 风险 | 缓解 |
|------|------|
| signData JSON 序列化不一致 | SDK 返回 sign_data_str，前端原样使用；测试覆盖序列化结果 |
| access_token 并发刷新 | Agent 原子操作 + 过期前 300s 缓冲 |
| 回调字段名大小写不一致 | 解析函数做容错映射 |
| app_key 泄露 | 文档强调 env 区分，prod.exs 单独配置 |
