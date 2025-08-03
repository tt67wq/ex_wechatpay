defmodule ExWechatpay.Core.RequestBuilder do
  @moduledoc """
  负责构建微信支付 API 请求

  该模块封装了 HTTP 请求的构建逻辑，包括请求参数处理、请求体构造等。
  通过将请求构建逻辑独立出来，提高了代码的可维护性和可测试性。
  """

  alias ExWechatpay.Core.SignatureManager
  alias ExWechatpay.Model.Http
  alias ExWechatpay.Typespecs

  @doc """
  构建微信支付 API 请求

  ## 参数
    * `config` - 配置选项
    * `method` - HTTP 方法，如 `:get`、`:post` 等
    * `api` - API 路径
    * `params` - 查询参数
    * `body` - 请求体
    * `opts` - 选项

  ## 返回值
    * `Http.Request.t()` - HTTP 请求结构
  """
  @spec build_request(
          Typespecs.config_t(),
          Typespecs.method(),
          Typespecs.api(),
          Typespecs.params(),
          Typespecs.body(),
          Keyword.t()
        ) :: Http.Request.t()
  def build_request(config, method, api, params, body, opts \\ []) do
    # 生成授权信息
    auth = SignatureManager.generate_authorization(config, method, api, params, body)

    # 构建请求头
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", auth}
    ]

    # 返回请求结构
    %Http.Request{
      host: config[:service_host],
      method: method,
      path: api,
      headers: headers,
      body: body,
      params: params,
      opts: opts
    }
  end

  @doc """
  扩展请求参数，添加公共字段

  ## 参数
    * `config` - 配置选项
    * `args` - 原始参数

  ## 返回值
    * `{:ok, binary()}` - 编码后的 JSON 字符串
  """
  @spec extend_args(Typespecs.config_t(), map()) :: {:ok, binary()}
  def extend_args(config, args) do
    args
    |> Map.put_new("appid", config[:appid])
    |> Map.put_new("mchid", config[:mchid])
    |> Map.put_new("notify_url", config[:notify_url])
    |> Jason.encode()
  end

  @doc """
  构建小程序支付表单

  ## 参数
    * `config` - 配置选项
    * `prepay_id` - 预支付 ID

  ## 返回值
    * `map()` - 小程序支付表单
  """
  @spec build_miniapp_payform(Typespecs.config_t(), String.t()) :: %{
          required(String.t()) => String.t()
        }
  def build_miniapp_payform(config, prepay_id) do
    alias ExWechatpay.Util

    ts = Util.timestamp()
    nonce = Util.random_string(12)
    package = "prepay_id=#{prepay_id}"
    signature = SignatureManager.sign_miniapp(config, ts, nonce, package)

    %{
      "appId" => config[:appid],
      "timeStamp" => ts,
      "nonceStr" => nonce,
      "package" => package,
      "signType" => "RSA",
      "paySign" => signature
    }
  end
end
