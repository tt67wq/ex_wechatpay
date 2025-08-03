defmodule ExWechatpay.Core.ResponseHandler do
  @moduledoc """
  响应处理模块

  该模块负责处理微信支付 API 的响应，包括响应验证、解析和数据转换等。
  通过集中处理响应逻辑，提高了代码的可维护性和一致性。
  """

  alias ExWechatpay.Core.SignatureManager
  alias ExWechatpay.Exception
  alias ExWechatpay.Model.Http
  alias ExWechatpay.Typespecs

  @doc """
  验证并处理 HTTP 响应

  ## 参数
    * `config` - 配置选项
    * `resp` - HTTP 响应

  ## 返回值
    * `{:ok, map()}` - 验证通过的响应数据
    * `{:error, Exception.t()}` - 验证失败的错误信息
  """
  @spec verify_and_parse_response(Typespecs.config_t(), Typespecs.http_response()) :: Typespecs.result_t(map())
  def verify_and_parse_response(config, resp) do
    %Http.Response{headers: headers, body: body} = resp

    config
    |> SignatureManager.verify_signature(headers, body)
    |> if do
      case body do
        "" -> {:ok, %{}}
        nil -> {:ok, %{}}
        _ -> Jason.decode(body)
      end
    else
      {:error, Exception.new("wechatpay verify failed", %{"headers" => headers, "body" => body})}
    end
  end

  @doc """
  解密微信支付加密数据

  ## 参数
    * `config` - 配置选项
    * `encrypted_form` - 加密数据
    * `tag_length` - 标签长度，默认为 16

  ## 返回值
    * `binary() | :error` - 解密后的数据或错误
  """
  @spec decrypt(Typespecs.config_t(), Typespecs.encrypted_resource(), non_neg_integer()) :: binary() | :error
  def decrypt(
        config,
        %{
          "algorithm" => "AEAD_AES_256_GCM",
          "associated_data" => aad,
          "ciphertext" => encoded_ciphertext,
          "nonce" => nonce
        },
        tag_length \\ 16
      ) do
    with {:ok, ciphertext} <- Base.decode64(encoded_ciphertext) do
      size_total = byte_size(ciphertext)
      ctext_len = size_total - tag_length
      <<ctext::binary-size(ctext_len), tag::binary-size(tag_length)>> = ciphertext

      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        config[:apiv3_key],
        nonce,
        ctext,
        aad,
        tag,
        false
      )
    end
  end

  @doc """
  解密并处理证书数据

  ## 参数
    * `certificates` - 证书数据列表
    * `config` - 配置选项

  ## 返回值
    * `[map()]` - 解密后的证书数据列表
  """
  @spec decrypt_certificates([map()], Typespecs.config_t()) :: [Typespecs.wx_cert()]
  def decrypt_certificates(certificates, config) do
    Enum.map(certificates, fn %{"encrypt_certificate" => encrypt_certificate} = x ->
      Map.put(x, "certificate", decrypt(config, encrypt_certificate))
    end)
  end
end
