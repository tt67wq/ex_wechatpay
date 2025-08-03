defmodule ExWechatpay.Core.SignatureManager do
  @moduledoc """
  签名管理模块

  该模块负责处理与微信支付 API 相关的所有签名操作，包括生成请求签名、验证响应签名等。
  通过集中管理签名逻辑，提高了代码的安全性和可维护性。
  """

  alias ExWechatpay.Model.ConfigOption
  alias ExWechatpay.Typespecs
  alias ExWechatpay.Util

  @doc """
  生成 API 请求的授权信息

  ## 参数
    * `config` - 配置选项
    * `method` - HTTP 方法
    * `api` - API 路径
    * `params` - 查询参数
    * `body` - 请求体

  ## 返回值
    * `String.t()` - 授权字符串
  """
  @spec generate_authorization(
          ConfigOption.t(),
          Typespecs.method(),
          Typespecs.api(),
          Typespecs.params(),
          Typespecs.body()
        ) :: String.t()
  def generate_authorization(config, method, api, params, body) do
    {http_method, body} =
      case method do
        :post -> {"POST", body}
        :get -> {"GET", ""}
      end

    url =
      api <>
        if params in [%{}, nil] do
          ""
        else
          "?" <> URI.encode_query(params)
        end

    ts = System.system_time(:second)
    nonce_str = Util.random_string(12)

    string_to_sign = "#{http_method}\n#{url}\n#{ts}\n#{nonce_str}\n#{body}\n"

    signature =
      string_to_sign
      |> :public_key.sign(:sha256, config[:client_key])
      |> Base.encode64()

    "WECHATPAY2-SHA256-RSA2048 " <>
      "mchid=\"#{config[:mchid]}\",nonce_str=\"#{nonce_str}\",timestamp=\"#{ts}\",serial_no=\"#{config[:client_serial_no]}\",signature=\"#{signature}\""
  end

  @doc """
  为小程序支付生成签名

  ## 参数
    * `config` - 配置选项
    * `ts` - 时间戳
    * `nonce` - 随机字符串
    * `package` - 包含预支付 ID 的字符串

  ## 返回值
    * `String.t()` - Base64 编码的签名
  """
  @spec sign_miniapp(ConfigOption.t(), integer(), String.t(), String.t()) :: String.t()
  def sign_miniapp(config, ts, nonce, package) do
    string_to_sign = "#{config[:appid]}\n#{ts}\n#{nonce}\n#{package}\n"

    string_to_sign
    |> :public_key.sign(:sha256, config[:client_key])
    |> Base.encode64()
  end

  @doc """
  验证微信支付回调或响应签名

  ## 参数
    * `config` - 配置选项
    * `headers` - HTTP 响应头
    * `body` - HTTP 响应体

  ## 返回值
    * `boolean()` - 验证结果，`true` 表示验证通过
  """
  @spec verify_signature(ConfigOption.t(), Typespecs.headers(), Typespecs.body()) :: boolean()
  def verify_signature(config, headers, body) do
    headers = Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)

    with {_, wx_pub} <-
           Enum.find(config[:wx_pubs], fn {x, _} -> x == headers["wechatpay-serial"] end),
         ts = headers["wechatpay-timestamp"],
         nonce = headers["wechatpay-nonce"],
         string_to_sign = "#{ts}\n#{nonce}\n#{body}\n",
         encoded_wx_signature = headers["wechatpay-signature"],
         {:ok, wx_signature} <- Base.decode64(encoded_wx_signature) do
      :public_key.verify(string_to_sign, :sha256, wx_signature, wx_pub)
    end
  end
end
