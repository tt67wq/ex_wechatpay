<!-- MDOC !-->
# 微信支付/WechatPay SDK in Elixir

该 SDK 提供了一种简单的方式来与微信支付 API 进行交互。它支持微信支付 API v3，包括付款、退款、查询订单等功能。

[![Hex.pm](https://img.shields.io/hexpm/v/ex_wechatpay.svg)](https://hex.pm/packages/ex_wechatpay)
[![Docs](https://img.shields.io/badge/hex-docs-green.svg)](https://hexdocs.pm/ex_wechatpay)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 安装

将 SDK 添加到你的 `mix.exs` 文件中：

```elixir
def deps do
  [
    {:ex_wechatpay, "~> 0.3"}
  ]
end
```

安装依赖：

```bash
mix deps.get
```

## 配置和使用

### 准备配置

在使用该 SDK 之前，应当提前准备好如下配置：

- `appid`: 第三方用户唯一凭证（微信公众号或小程序的 AppID）
- `mchid`: 商户号（微信支付分配的商户号）
- `notify_url`: 订单信息的回调地址（必须为 HTTPS）
- `apiv3_key`: [API v3 密钥](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay3_2.shtml)（用于解密微信支付回调中的敏感信息）
- `client_serial_no`: [商户 API 证书序列号](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)
- `client_key`: [商户 API 证书私钥](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)
- `client_cert`: [商户 API 证书](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)
- `wx_pubs`: [微信平台证书列表](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml)（用于验证微信支付回调的签名）

如果是首次使用，`wx_pubs` 可以暂时不配置，可以后续通过 `get_certificates/0` 获取并更新配置。

### 创建客户端

```elixir
defmodule MyWechat do
  use ExWechatpay, otp_app: :my_app

  def init(config) do
    # 可以在这里对配置进行预处理
    {:ok, config}
  end
end
```

### 配置客户端

在 `config/config.exs` 中配置：

```elixir
config :my_app, MyWechat,
  appid: "wxefd6b215fca0cacd",
  mchid: "1611120167",
  service_host: "api.mch.weixin.qq.com",  # 可选，默认为正式环境
  notify_url: "https://www.example.com/notify",
  apiv3_key: "A21AjklasMDKNmA91232D91281230",
  client_serial_no: "1C984734F30327FD63C46DA5386C086104",
  client_key: "-----BEGIN PRIVATE KEY-----.....-----END PRIVATE KEY-----\n",
  client_cert: "-----BEGIN CERTIFICATE-----.....-----END CERTIFICATE-----\n",
  timeout: 5000,  # 可选，请求超时时间，默认 5000 毫秒
  log_level: :info  # 可选，日志级别，默认 :info
```

### 启动客户端

在应用的 `application.ex` 中添加：

```elixir
def start(_type, _args) do
  children = [
    # 其他子进程
    MyWechat
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 使用示例

```elixir
# 获取微信平台证书列表
{:ok, certificates} = MyWechat.get_certificates()

# 更新证书配置
MyWechat.update_certificates()

# 启用自动更新证书（每天更新一次）
MyWechat.enable_auto_update_certificates()

# Native 下单（扫码支付）
{:ok, result} = MyWechat.create_native_transaction(%{
  "description" => "商品描述",
  "out_trade_no" => "ORDER_20230605001",  # 商户订单号，需保证唯一
  "amount" => %{
    "total" => 100,  # 金额，单位分，此处为 1 元
    "currency" => "CNY"
  }
})
# 返回 %{"code_url" => "weixin://wxpay/bizpayurl?pr=xxxx"}
# 将 code_url 生成二维码供用户扫码支付

# JSAPI 下单（公众号/小程序支付）
{:ok, result} = MyWechat.create_jsapi_transaction(%{
  "description" => "商品描述",
  "out_trade_no" => "ORDER_20230605002",
  "amount" => %{
    "total" => 100,
    "currency" => "CNY"
  },
  "payer" => %{
    "openid" => "oUpF8uMuAJO_M2pxb1Q9zNjWeS6o"  # 用户 OpenID
  }
})
# 返回 %{"prepay_id" => "wx2909490340590485a2c6d5a82031931600"}

# 生成小程序/公众号支付参数
pay_params = MyWechat.miniapp_payform(result["prepay_id"])
# 将 pay_params 传递给前端调用支付接口

# H5 下单（移动端网页支付）
{:ok, result} = MyWechat.create_h5_transaction(%{
  "description" => "商品描述",
  "out_trade_no" => "ORDER_20230605003",
  "amount" => %{
    "total" => 100,
    "currency" => "CNY"
  },
  "scene_info" => %{
    "payer_client_ip" => "127.0.0.1",
    "device_id" => "device_123"
  }
})
# 返回 %{"h5_url" => "https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?prepay_id=..."}
# 将用户引导到 h5_url 完成支付

# 查询订单（通过商户订单号）
{:ok, order} = MyWechat.query_transaction_by_out_trade_no("ORDER_20230605001")

# 查询订单（通过微信支付订单号）
{:ok, order} = MyWechat.query_transaction_by_transaction_id("4200001285202103303271489573")

# 关闭订单
:ok = MyWechat.close_transaction("ORDER_20230605001")

# 申请退款
{:ok, refund} = MyWechat.create_refund(%{
  "out_refund_no" => "REFUND_20230605001",  # 商户退款单号，需保证唯一
  "out_trade_no" => "ORDER_20230605001",
  "amount" => %{
    "refund" => 100,  # 退款金额，单位分
    "total" => 100,   # 原订单金额，单位分
    "currency" => "CNY"
  },
  "reason" => "商品已退货"  # 可选
})

# 查询退款
{:ok, refund_info} = MyWechat.query_refund("REFUND_20230605001")

# 验证回调通知签名
headers = [
  {"Wechatpay-Signature", "签名值"},
  {"Wechatpay-Serial", "证书序列号"},
  {"Wechatpay-Timestamp", "时间戳"},
  {"Wechatpay-Nonce", "随机字符串"}
]
body = "{\"transaction_id\":\"4200001285202103303271489573\"}"
is_valid = MyWechat.verify(headers, body)

# 处理退款结果通知
{:ok, notification} = MyWechat.handle_refund_notification(headers, body)
```

## 功能列表

### 基础功能
- [x] `get_config/0`: 获取当前配置
- [x] `update_config/1`: 更新配置

### 证书管理
- [x] `get_certificates/1`: 获取微信平台证书列表
- [x] `update_certificates/0`: 更新证书
- [x] `enable_auto_update_certificates/1`: 启用自动更新证书
- [x] `disable_auto_update_certificates/0`: 禁用自动更新证书

### 支付相关
- [x] `create_native_transaction/1`: Native 下单 API（扫码支付）
- [x] `create_jsapi_transaction/1`: JSAPI 下单 API（公众号/小程序支付）
- [x] `create_h5_transaction/1`: H5 下单 API（移动端网页支付）
- [x] `miniapp_payform/1`: 生成小程序/公众号支付参数

### 订单管理
- [x] `query_transaction_by_out_trade_no/1`: 通过商户订单号查询订单
- [x] `query_transaction_by_transaction_id/1`: 通过微信支付订单号查询订单
- [x] `close_transaction/1`: 关闭订单

### 退款相关
- [x] `create_refund/1`: 申请退款
- [x] `query_refund/1`: 查询退款
- [x] `handle_refund_notification/2`: 处理退款结果通知

### 工具函数
- [x] `verify/2`: 验证微信支付通知或响应签名
- [x] `decrypt/1`: 解密微信支付加密数据

## 回调处理示例

以 Phoenix 框架为例，处理支付和退款通知的回调：

```elixir
defmodule MyAppWeb.WechatPayController do
  use MyAppWeb, :controller

  def payment_notify(conn, _params) do
    {:ok, body, conn} = read_body(conn)
    headers = Enum.map(conn.req_headers, fn {k, v} -> {k, v} end)

    # 验证签名
    if MyWechat.verify(headers, body) do
      # 解析通知数据
      {:ok, decoded} = Jason.decode(body)

      # 处理通知（根据业务逻辑）
      process_payment_notification(decoded)

      # 返回成功响应
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{code: "SUCCESS", message: "成功"}))
    else
      # 签名验证失败
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(400, Jason.encode!(%{code: "FAIL", message: "签名验证失败"}))
    end
  end

  def refund_notify(conn, _params) do
    {:ok, body, conn} = read_body(conn)
    headers = Enum.map(conn.req_headers, fn {k, v} -> {k, v} end)

    # 处理退款通知
    case MyWechat.handle_refund_notification(headers, body) do
      {:ok, notification} ->
        # 处理退款结果（根据业务逻辑）
        process_refund_notification(notification)

        # 返回成功响应
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{code: "SUCCESS", message: "成功"}))

      {:error, _error} ->
        # 处理失败
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{code: "FAIL", message: "处理通知失败"}))
    end
  end

  defp process_payment_notification(notification) do
    # 实现支付通知处理逻辑
    # ...
  end

  defp process_refund_notification(notification) do
    # 实现退款通知处理逻辑
    # ...
  end
end
```

## 错误处理

SDK 使用 `{:ok, result}` 或 `{:error, exception}` 的格式返回结果，其中 `exception` 是一个包含错误信息的 `ExWechatpay.Exception` 结构。

```elixir
case MyWechat.create_native_transaction(params) do
  {:ok, result} ->
    # 处理成功结果
    code_url = result["code_url"]
    # ...

  {:error, %ExWechatpay.Exception{message: message, details: details}} ->
    # 处理错误
    Logger.error("微信支付下单失败: #{message}, 详情: #{inspect(details)}")
    # ...
end
```

## 证书管理

微信支付平台证书会定期更新，建议启用自动更新证书功能，确保验签功能正常工作：

```elixir
# 应用启动时启用自动更新证书（每天更新一次）
MyWechat.enable_auto_update_certificates()
```

或者定期手动更新证书：

```elixir
# 手动更新证书
MyWechat.update_certificates()
```

## 许可证

该 SDK 基于 MIT 许可证发布。有关更多信息，请参见 [LICENSE](LICENSE) 文件。

## 联系方式

如果你有任何问题或反馈，请发送电子邮件至 tt67wq@outlook.com 或者发起 issue。
