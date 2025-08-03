defmodule ExWechatpay.Config.Schema do
  @moduledoc """
  配置模式模块

  该模块定义了 ExWechatpay 的配置模式，用于验证配置的正确性。
  通过使用 NimbleOptions 提供强大的配置验证功能，确保应用程序的配置符合预期。
  """

  @config_schema [
    appid: [
      type: :string,
      required: true,
      doc: "第三方用户唯一凭证（微信公众号或小程序的 AppID）"
    ],
    mchid: [
      type: :string,
      required: true,
      doc: "商户号（微信支付分配的商户号）"
    ],
    service_host: [
      type: :string,
      default: "api.mch.weixin.qq.com",
      doc: "微信支付服务域名（默认为正式环境，沙箱环境可设置为 'api.mch.weixin.qq.com/sandboxnew'）"
    ],
    notify_url: [
      type: :string,
      required: true,
      doc: "通知地址（微信支付结果通知回调地址，必须为 https 协议）"
    ],
    apiv3_key: [
      type: :string,
      default: "",
      doc: "APIv3密钥（用于解密微信支付回调中的敏感信息，请在商户平台设置并保存）"
    ],
    wx_pubs: [
      type: {:list, :any},
      default: [],
      doc: """
      微信平台证书列表（用于验证微信支付回调请求）
      格式为 [{serial_no, cert_content}, ...]
      可以通过 get_certificates/0 API 获取最新的证书列表
      """
    ],
    client_serial_no: [
      type: :string,
      required: true,
      doc: """
      商户API证书序列号
      可通过以下命令从证书中提取：
      openssl x509 -in apiclient_cert.pem -noout -serial | cut -d= -f2 | tr 'A-F' 'a-f'
      """
    ],
    client_key: [
      type: {:or, [:string, :any]},
      required: true,
      doc: """
      商户API证书私钥
      可以是私钥文件路径，私钥内容字符串，或已加载的私钥对象
      """
    ],
    client_cert: [
      type: {:or, [:string, :any]},
      required: true,
      doc: """
      商户API证书
      可以是证书文件路径，证书内容字符串，或已加载的证书对象
      """
    ],
    timeout: [
      type: :pos_integer,
      default: 5000,
      doc: "请求超时时间（毫秒）"
    ],
    retry: [
      type: :boolean,
      default: false,
      doc: "是否启用请求重试机制"
    ],
    retry_times: [
      type: :pos_integer,
      default: 3,
      doc: "请求重试次数（仅当 retry 为 true 时有效）"
    ],
    retry_delay: [
      type: :pos_integer,
      default: 1000,
      doc: "请求重试间隔（毫秒，仅当 retry 为 true 时有效）"
    ],
    log_level: [
      type: {:in, [:debug, :info, :warn, :error, :none]},
      default: :info,
      doc: "日志级别"
    ]
  ]

  @type t :: keyword(unquote(NimbleOptions.option_typespec(@config_schema)))

  @doc """
  验证配置

  ## 参数
    * `opts` - 要验证的配置选项

  ## 返回值
    * `{:ok, validated_config}` - 验证通过的配置
    * `{:error, error}` - 验证失败的错误信息
  """
  @spec validate(keyword()) :: {:ok, keyword()} | {:error, term()}
  def validate(opts) do
    NimbleOptions.validate(opts, @config_schema)
  end

  @doc """
  验证配置（如果验证失败则抛出异常）

  ## 参数
    * `opts` - 要验证的配置选项

  ## 返回值
    * `validated_config` - 验证通过的配置

  ## 异常
    * 如果验证失败，抛出 `NimbleOptions.ValidationError` 异常
  """
  @spec validate!(keyword()) :: keyword()
  def validate!(opts) do
    NimbleOptions.validate!(opts, @config_schema)
  end

  @doc """
  获取配置模式

  ## 返回值
    * `config_schema` - 配置模式
  """
  @spec schema() :: keyword()
  def schema do
    @config_schema
  end

  @doc """
  生成配置文档

  ## 返回值
    * `docs` - 配置文档（Markdown 格式）
  """
  @spec docs() :: binary()
  def docs do
    NimbleOptions.docs(@config_schema)
  end
end
