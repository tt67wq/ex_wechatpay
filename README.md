<!-- MDOC !-->
# 微信支付/WechatPay SDK in Elixir
该SDK提供了一种简单的方式来与微信支付API进行交互。它包括了部分微信支付API，包括付款、退款、查询订单等。

[Online Document](https://hexdocs.pm/ex_wechatpay)

## 安装
---
将SDK添加到你的mix.exs文件中：

```Elixir
def deps do
  [
    {:ex_wechatpay, "~> 0.2"}
  ]
end
```

## Usage
---
1. 在使用该SDK之前，应当提前准备好如下配置：

- appid: 第三方用户唯一凭证；
- mchid: 商户号;
- notify_url: 订单信息的回调地址；
- apiv3_key: [apiv3密钥](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay3_2.shtml)
- wx_pubs: [微信平台证书列表](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml)，如果是首次使用可不配置，用`ExWechatpay.get_certificates`可下载证书信息
- client_serial_no: [商户API证书序列号](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)，如果是首次使用可不配置，用`ExWechatpay.get_certificates`可下载证书信息
- client_key: [商户API证书私钥](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)
- client_cert: [商户API证书](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)

假设配置如下：
```Elixir
config = [
     
  ]
```

2. 生成一个客户端
```Elixir
defmodule MyWechat do
  use ExWechatpay, otp_app: :my_app

  def init(config) do
    # do some config prepare work here
    {:ok, config}
  end
end
```

3. 配置客户端
```Elixir
config :my_app, MyWechat
   appid: "wxefd6b2150cac",
   mchid: "1611167",
   notify_url: "https://www.example.com",
   apiv3_key: "A21AjklasMDKNmA1232D91281230",
   client_serial_no: "1C984734F30327FD63C46DA5386C086104",
   client_key: "-----BEGIN PRIVATE KEY-----.....-----END PRIVATE KEY-----\n",
   client_cert: "-----BEGIN CERTIFICATE-----.....-----END CERTIFICATE-----\n",
   wx_pubs: [
       {
           "wechatpay-serial": "35CE31ED8F4A5037C51B5ADA03265E72",
           "public_key": "-----BEGIN PUBLIC KEY-----.....-----END PUBLIC KEY-----\n"
       }
   ]
```

4. Enjoy your journey!
```Elixir
# 获取微信平台证书列表
ExWechatpay.get_certificates()

# Native下单API
ExWechatpay.create_native_transaction(
  %{
     "description" => "Image形象店-深圳腾大-QQ公仔",
     "out_trade_no" => Util.random_string(12),
     "notify_url" => "https://www.weixin.qq.com/wxpay/pay.php",
     "amount" => %{
       "total" => 1,
       "currency" => "CNY"
     }
   }
)
```

## 功能列表：

- [x] get_certificates: 获取微信平台证书列表
- [x] verify: 验证微信回调签名
- [x] create_native_transaction: Native下单API
- [x] create_jsapi_transaction: JSAPI下单API
- [x] create_h5_transaction: H5下单API
- [x] query_transaction: 查询订单API
- [x] close_transaction: 关闭订单API
- [x] miniapp_payform: 小程序生成支付表单
- [x] create_refund: 申请退款API


## 许可证
---
该SDK基于MIT许可证发布。有关更多信息，请参见LICENSE文件。


## 联系方式
---
如果你有任何问题或反馈，请发送电子邮件至tt67wq@outlook.com或者发起issue。



