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
    {:ex_wechatpay, "~> 0.1"}
  ]
end
```

运行mix deps.get来安装SDK。


## Usage
---
在使用该SDK之前，应当提前准备好如下配置：

- appid: 第三方用户唯一凭证；
- mchid: 商户号;
- notify_url: 订单信息的回调地址；
- apiv3_key: [apiv3密钥](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay3_2.shtml)
- wx_pubs: [微信平台证书列表](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml)，如果是首次使用可不配置，用`ExWechatpay.get_certificates/2`可下载证书信息
- client_serial_no: [商户API证书序列号](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)，如果是首次使用可不配置，用`ExWechatpay.get_certificates/2`可下载证书信息
- client_key: [商户API证书私钥](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)
- client_cert: [商户API证书](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml)
- http_module: HTTP客户端模块(实现了ExWechatpay.Http behaviour)，默认使用ExWechatpay.Http.Finch
- http_client: HTTP客户端实例，如果http_module为ExWechatpay.Http.Finch, http_client为ExWechatpay.Http.Finch.new()


假设配置如下：
```json
// test_data
{
     "appid": "wxefd6b2150cac",
     "mchid": "1611167",
     "notify_url": "https://www.example.com",
     "apiv3_key": "A21AjklasMDKNmA1232D91281230",
     "client_serial_no": "1C984734F30327FD63C46DA5386C086104",
     "client_key": "-----BEGIN PRIVATE KEY-----.....-----END PRIVATE KEY-----\n",
     "client_cert": "-----BEGIN CERTIFICATE-----.....-----END CERTIFICATE-----\n",
     "wx_pubs": [
         {
             "wechatpay-serial": "35CE31ED8F4A5037C51B5ADA03265E72",
             "public_key": "-----BEGIN PUBLIC KEY-----.....-----END PUBLIC KEY-----\n"
         }
     ]
 }
```

使用客户端前，先初始化一个client实例:

```Elixir
iex> test_data = File.read!("test.json") |> Jason.decode!()
     
iex> client =
  ExWechatpay.Client.new(
    appid: test_data["appid"],
    mchid: test_data["mchid"],
    notify_url: test_data["notify_url"],
    apiv3_key: test_data["apiv3_key"],
    client_serial_no: test_data["client_serial_no"],
    client_key: test_data["client_key"],
    client_cert: test_data["client_cert"],
    wx_pubs:
      test_data["wx_pubs"] |> Enum.map(fn x -> {x["wechatpay-serial"], x["public_key"]} end)
  )
```

再启动SDK实例即可使用:

```Elixir
iex> wechat = ExWechatpay.new(client: client)
iex> ExWechatpay.start_link(wechat: wechat)

iex> ExWechatpay.get_certificates(wechat, verify: false) # 首次获取微信平台证书列表时可设置不验证
{
  :ok,
  %{
    "data" => [
      %{
        "certificate" => "-----BEGIN CERTIFICATE-----\nMIID3DCCAsSgAwIBAgIUNc4x7Y9KULkw...\n-----END CERTIFICATE-----",
        "effective_time" => "2021-06-23T14:09:22+08:00",
        "encrypt_certificate" => %{
          "algorithm" => "AEAD_AES_256_GCM",
          "associated_data" => "certificate",
          "ciphertext" => "BoiqBLxeEtXMAmD7pm+...w==",
          "nonce" => "2862867afb33"
        },
        "expire_time" => "2026-06-22T14:09:22+08:00",
        "serial_no" => "35CE31ED8F4A50B930FF8D37C51B5ADA03265E72"
      }
    ]
  }
}
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



