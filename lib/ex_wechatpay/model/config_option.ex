defmodule ExWechatpay.Model.ConfigOption do
  @moduledoc false

  @config_options_schema [
    appid: [
      type: :string,
      required: true,
      doc: "第三方用户唯一凭证"
    ],
    mchid: [
      type: :string,
      required: true,
      doc: "商户号"
    ],
    service_host: [
      type: :string,
      default: "api.mch.weixin.qq.com",
      doc: "微信支付服务域名"
    ],
    notify_url: [
      type: :string,
      required: true,
      doc: "通知地址"
    ],
    apiv3_key: [
      type: :string,
      default: "",
      doc: "APIv3密钥, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay3_2.shtml for more details"
    ],
    wx_pubs: [
      type: {:list, :any},
      default: [{"wechatpay-serial", "pem"}],
      doc: "微信平台证书列表, see https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml for more details"
    ],
    client_serial_no: [
      type: :string,
      required: true,
      doc: "商户API证书序列号, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml for more details"
    ],
    client_key: [
      type: :string,
      required: true,
      doc: "商户API证书私钥, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml for more details"
    ],
    client_cert: [
      type: :string,
      required: true,
      doc: "商户API证书, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml for more details"
    ]
  ]

  @type t :: keyword(unquote(NimbleOptions.option_typespec(@config_options_schema)))

  def validate(opts) do
    NimbleOptions.validate(opts, @config_options_schema)
  end
end
