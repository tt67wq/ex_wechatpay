defmodule ExWechatpay.Core.CertificateManager do
  @moduledoc """
  证书管理模块

  该模块负责处理微信支付平台证书的获取、存储和管理。
  通过集中管理证书逻辑，提高了代码的安全性和可维护性。
  """

  alias ExWechatpay.Core.RequestBuilder
  alias ExWechatpay.Core.ResponseHandler
  alias ExWechatpay.Core.SignatureManager
  alias ExWechatpay.Exception
  alias ExWechatpay.Model.ConfigOption
  alias ExWechatpay.Model.Http.Response
  alias ExWechatpay.Typespecs

  @type ok_t(ret) :: {:ok, ret}
  @type err_t() :: {:error, Exception.t()}

  @doc """
  获取微信支付平台证书

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `verify` - 是否验证证书，默认为 true

  ## 返回值
    * `{:ok, map()}` - 成功获取的证书信息
    * `{:error, Exception.t()}` - 获取证书失败的错误信息
  """
  @spec get_certificates(ConfigOption.t(), Typespecs.name(), boolean()) ::
          {:ok, Typespecs.dict()} | err_t()
  def get_certificates(config, finch, verify \\ true) do
    # 构建请求
    request = RequestBuilder.build_request(config, :get, "/v3/certificates", %{}, nil)

    with {:ok, %Response{body: body, headers: headers}} <- ExWechatpay.Http.do_request(finch, request) do
      if verify do
        config
        |> SignatureManager.verify_signature(headers, body)
        |> if do
          {:ok, %{"data" => data}} = Jason.decode(body)
          {:ok, %{"data" => ResponseHandler.decrypt_certificates(data, config)}}
        else
          {:error, Exception.new("verify_failed", %{"headers" => headers, "body" => body})}
        end
      end
    end
  end

  @doc """
  更新配置中的微信支付平台证书

  这个函数用于自动更新配置中的平台证书。
  当证书接近过期时，应该调用此函数获取最新的证书。

  ## 参数
    * `config` - 当前配置
    * `finch` - Finch 实例

  ## 返回值
    * `{:ok, ConfigOption.t()}` - 更新后的配置
    * `{:error, Exception.t()}` - 更新失败的错误信息
  """
  @spec update_certificates(ConfigOption.t(), Typespecs.name()) :: {:ok, ConfigOption.t()} | err_t()
  def update_certificates(config, finch) do
    with {:ok, %{"data" => certificates}} <- get_certificates(config, finch) do
      # 将证书更新到配置中
      updated_wx_pubs =
        Enum.map(certificates, fn %{"serial_no" => serial_no, "certificate" => cert} ->
          {serial_no, cert}
        end)

      # 返回更新后的配置
      {:ok, Keyword.put(config, :wx_pubs, updated_wx_pubs)}
    end
  end

  @doc """
  检查证书是否需要更新

  ## 参数
    * `config` - 配置选项

  ## 返回值
    * `boolean()` - 是否需要更新证书
  """
  @spec needs_certificate_update?(ConfigOption.t()) :: boolean()
  def needs_certificate_update?(config) do
    # 检查是否存在平台证书
    case config[:wx_pubs] do
      [] -> true
      nil -> true
      _ -> false
    end

    # 注意：这里可以扩展更多的逻辑，比如检查证书是否即将过期等
  end
end
