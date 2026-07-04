# 虚拟支付使用指南

本文档介绍如何使用 ex_wechatpay SDK 的虚拟支付功能（`wx.requestVirtualPayment`）。

虚拟支付用于小程序内购买虚拟商品（会员、道具、代币等），走微信 `api.weixin.qq.com/xpay/*` 接口，与现有 v3 支付（`api.mch.weixin.qq.com/v3/*`）是完全不同的 API 体系。

## 目录

- [前置条件](#前置条件)
- [配置](#配置)
- [生成支付签名](#生成支付签名)
- [xpay 服务端接口](#xpay-服务端接口)
- [回调处理](#回调处理)
- [签名工具函数](#签名工具函数)
- [前端集成](#前端集成)
- [完整流程示例](#完整流程示例)
- [常见问题](#常见问题)

---

## 前置条件

1. 小程序已在微信后台开通虚拟支付功能
2. 获得以下凭据：
   - **AppID** — 小程序 AppID（与 v3 支付共用）
   - **Secret** — 小程序密钥（与 v3 支付共用）
   - **OfferID** — 虚拟支付应用 ID（微信虚拟支付后台分配）
   - **AppKey** — 虚拟支付现网密钥
   - **AppKey (Sandbox)** — 虚拟支付沙箱密钥

---

## 配置

### config/config.exs

在现有配置中添加 `secret` 和 `virtual_pay` 子键：

```elixir
config :my_app, MyWechat,
  appid: "wxefd6b215fca0cacd",
  secret: "your_miniapp_secret",   # ← 新增，虚拟支付 code2session 需要
  mchid: "1611120167",
  notify_url: "https://example.com/notify",
  apiv3_key: "your_apiv3_key",
  client_serial_no: "YOUR_CERT_SERIAL",
  client_key: "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  client_cert: "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n",
  virtual_pay: %{                   # ← 新增，虚拟支付配置
    offer_id: "1450549278",
    app_key: "your_production_app_key",
    app_key_sandbox: "your_sandbox_app_key",
    env: 1                          # 1=沙箱, 0=正式
  }
```

### config/prod.exs

生产环境覆盖为正式环境：

```elixir
config :my_app, MyWechat,
  virtual_pay: %{
    offer_id: "1450549278",
    app_key: "your_production_app_key",
    app_key_sandbox: "",
    env: 0   # 正式环境
  }
```

### 配置项说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `secret` | string | 是 | 小程序密钥，用于 code2session 和 access_token |
| `virtual_pay.offer_id` | string | 是 | 虚拟支付应用 ID |
| `virtual_pay.app_key` | string | 是 | 现网 AppKey |
| `virtual_pay.app_key_sandbox` | string | 否 | 沙箱 AppKey（env=1 时使用） |
| `virtual_pay.env` | 0 \| 1 | 否 | 环境，默认 1（沙箱） |

配置了 `virtual_pay` 后，SDK 会自动启动 `TokenAgent` 进程缓存 access_token（7200s 有效期，过期前 300s 自动刷新）。

---

## 生成支付签名

`virtual_pay_sign/1` 是最核心的函数，一步完成：code2session → 组装 signData → 计算所有签名。

```elixir
{:ok, result} = MyWechat.virtual_pay_sign(
  product_id: "vip_six_week",
  out_trade_no: "VP" <> to_string(:os.system_time(:millisecond)),
  code: "0a1b2c0X1abcZ0X1bcZ1",   # 前端 wx.login() 获取
  goods_price: 3000                # 单位：分（30 元）
)

# result 包含：
# %{
#   sign_data: %{...},        # signData 对象（前端逐字段取值）
#   sign_data_str: "{...}",   # signData JSON 字符串（前端原样传给微信）
#   pay_sig: "a1b2c3...",     # 客户端支付签名
#   signature: "d4e5f6...",   # 用户态签名
#   session_key: "..."        # 用户 session_key
# }
```

### 返回值字段说明

| 字段 | 用途 |
|------|------|
| `sign_data` | signData 对象，前端用来逐字段填 `wx.requestVirtualPayment` 参数 |
| `sign_data_str` | signData 的 JSON 字符串，前端**原样**作为 `signData` 参数传给微信 |
| `pay_sig` | 客户端支付签名，作为 `paySig` 参数 |
| `signature` | 用户态签名，作为 `signature` 参数 |
| `session_key` | 用户 session_key（可用于后续业务逻辑） |

> ⚠️ **铁律**：`sign_data_str` 必须原样传给前端，前端**不能再 `JSON.stringify`**。否则字节不一致会导致 `SIGNATURE_INVALID`。

---

## xpay 服务端接口

### 查询代币余额

```elixir
{:ok, balance} = MyWechat.virtual_pay_query_balance(openid, "127.0.0.1")
```

### 查询订单状态

```elixir
{:ok, order} = MyWechat.virtual_pay_query_order(openid, "VP1719000000000")
# order["order_status"]: 0=未支付, 1=已支付未发货, 2=已发货
```

### 发起退款

```elixir
{:ok, refund} = MyWechat.virtual_pay_refund(openid, "VP1719000000000", 3000)
# refund_fee 单位：分
```

### 通知发货

```elixir
{:ok, _} = MyWechat.virtual_pay_notify_deliver(openid, "VP1719000000000")
```

### code2session（单独使用）

```elixir
{:ok, %{session_key: sk, openid: od}} = MyWechat.virtual_pay_code2session(code)
```

---

## 回调处理

微信虚拟支付有两个回调，**不鉴权**（无签名验证），SDK 提供解析工具函数。

### 发货回调

```elixir
# Phoenix controller 示例
def xpay_deliver(conn, params) do
  case ExWechatpay.VirtualPay.Callback.parse_deliver(params) do
    {:ok, %{openid: openid, out_trade_no: out_trade_no, product_id: product_id}} ->
      # 你的发货逻辑（开通 VIP 等）
      MyApp.Delivery.deliver(openid, product_id, out_trade_no)

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(ExWechatpay.VirtualPay.Callback.success_response()))

    {:error, reason} ->
      # 记录日志
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{"ErrCode" => -1, "ErrMsg" => "parse error"}))
  end
end
```

### 退款回调

```elixir
def xpay_refund(conn, params) do
  case ExWechatpay.VirtualPay.Callback.parse_refund(params) do
    {:ok, %{openid: openid, wx_refund_id: refund_id, refund_fee: fee, ret_code: code}} ->
      # 你的退款处理逻辑
      MyApp.Refund.handle(openid, refund_id, fee, code)

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(ExWechatpay.VirtualPay.Callback.success_response()))

    {:error, _} ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{"ErrCode" => -1, "ErrMsg" => "error"}))
  end
end
```

### 回调解析容错

`parse_deliver/1` 和 `parse_refund/1` 自动处理字段名大小写差异：

```elixir
# 以下两种格式都能正确解析：
ExWechatpay.VirtualPay.Callback.parse_deliver(~s({"OpenId":"xxx","OutTradeNo":"VP123"}))
ExWechatpay.VirtualPay.Callback.parse_deliver(~s({"openid":"xxx","out_trade_no":"VP123"}))
# 都返回 {:ok, %{openid: "xxx", out_trade_no: "VP123", product_id: nil}}
```

---

## 签名工具函数

通常不需要直接调用（`virtual_pay_sign/1` 已封装），但如果需要自定义签名逻辑：

```elixir
alias ExWechatpay.VirtualPay.Signature

# 服务端 API 签名（调 xpay 接口用）
sig = Signature.pay_sig(app_key, "/xpay/query_user_balance", body_json)

# 客户端签名（返回给前端 wx.requestVirtualPayment）
sig = Signature.client_pay_sig(app_key, sign_data_str)
# 内部自动加 "requestVirtualPayment&" 前缀

# 用户态签名（用 session_key）
sig = Signature.user_signature(session_key, sign_data_str)
```

所有签名输出均为 **hex 小写** 64 字符字符串。

---

## 前端集成

### 小程序端调用流程

```javascript
// 1. 登录拿 code
wx.login({
  success(res) {
    const code = res.code

    // 2. 请求后端生成签名
    wx.request({
      url: 'https://your-server.com/api/virtual_pay/sign',
      method: 'POST',
      data: {
        product_id: 'vip_six_week',
        out_trade_no: 'VP' + Date.now().toString(36) + randomStr(6),
        code: code,
        goods_price: 3000
      },
      success(res) {
        const data = res.data.data

        // 3. 拉起虚拟支付
        wx.requestVirtualPayment({
          env: data.sign_data.env,
          offerId: data.sign_data.offerId,
          currencyType: data.sign_data.currencyType,
          platform: "android",
          buyQuantity: data.sign_data.buyQuantity,
          zoneId: "",
          mode: data.sign_data.mode,
          productId: data.sign_data.productId,
          goodsPrice: data.sign_data.goodsPrice,
          outTradeNo: data.sign_data.outTradeNo,
          attach: data.sign_data.attach,
          signData: data.sign_data_str,   // ⚠️ 原样传入，不要 JSON.stringify
          paySig: data.pay_sig,
          signature: data.signature,
          success(res) {
            console.log('支付成功', res)
          },
          fail(err) {
            console.log('支付失败', err)
          }
        })
      }
    })
  }
})
```

> ⚠️ `signData` 参数必须传 `sign_data_str`（后端返回的 JSON 字符串原串），**不能**用 `JSON.stringify(data.sign_data)` 重新序列化。

---

## 完整流程示例

### Phoenix Controller 实现

```elixir
defmodule MyAppWeb.VirtualPayController do
  use MyAppWeb, :controller

  alias ExWechatpay.VirtualPay.Callback

  # POST /api/virtual_pay/sign
  def sign(conn, %{"product_id" => pid, "out_trade_no" => otn,
                    "code" => code, "goods_price" => price}) do
    case MyApp.Wechat.virtual_pay_sign(
      product_id: pid,
      out_trade_no: otn,
      code: code,
      goods_price: price
    ) do
      {:ok, result} ->
        json(conn, %{code: 200, data: result})

      {:error, e} ->
        json(conn, %{code: 500, message: e.message})
    end
  end

  # POST /api/notify/xpay_deliver
  def deliver(conn, params) do
    case Callback.parse_deliver(params) do
      {:ok, %{openid: openid, out_trade_no: otn, product_id: pid}} ->
        # 发货逻辑（开通 VIP 等）
        MyApp.Delivery.deliver(openid, pid, otn)
        json(conn, Callback.success_response())

      {:error, _} ->
        json(conn, %{"ErrCode" => -1, "ErrMsg" => "parse error"})
    end
  end

  # POST /api/notify/xpay_refund
  def refund_notify(conn, params) do
    case Callback.parse_refund(params) do
      {:ok, %{openid: openid, wx_refund_id: rid, refund_fee: fee, ret_code: rc}} ->
        MyApp.Refund.handle(openid, rid, fee, rc)
        json(conn, Callback.success_response())

      {:error, _} ->
        json(conn, %{"ErrCode" => -1, "ErrMsg" => "parse error"})
    end
  end
end
```

---

## 常见问题

### SIGNATURE_INVALID

**原因**：`sign_data_str` 字节不一致。前端用 `JSON.stringify` 重新序列化了 signData。

**解决**：前端必须使用后端返回的 `sign_data_str` 原串。

### PAY_SIG_INVALID (-15006)

**原因**：paySig 缺少 `requestVirtualPayment&` 前缀。

**解决**：SDK 的 `Signature.client_pay_sig/2` 已自动添加前缀，确保使用 SDK 函数而非手动拼接。

### PRODUCT_ID_NOT_PUBLISH

**原因**：道具没在正式环境发布。

**解决**：联调时 `env: 1` 走沙箱环境。

### access_token 获取失败

**原因**：appid 或 secret 配置错误。

**解决**：确认 `config` 中的 `appid` 和 `secret` 正确。SDK 内部 `TokenAgent` 会自动缓存和刷新 token。

### 沙箱 vs 正式环境

- `env: 1`（沙箱）：使用 `app_key_sandbox`，不产生真实扣款
- `env: 0`（正式）：使用 `app_key`，真实扣款
- 沙箱环境微信通常不推发货回调，需要后端轮询 `query_order` 兜底
