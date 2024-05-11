defmodule ExWechatpay.Core do
  @moduledoc false

  use Agent

  alias ExWechatpay.Exception
  alias ExWechatpay.Model.ConfigOption
  alias ExWechatpay.Model.Http
  alias ExWechatpay.Typespecs
  alias ExWechatpay.Util

  @type ok_t(ret) :: {:ok, ret}
  @type err_t() :: {:error, Exception.t()}

  @http_impl ExWechatpay.Http.Finch
  @tag_length 16

  def start_link({name, config}) do
    Agent.start_link(fn -> config end, name: name)
  end

  def get(name) do
    Agent.get(name, & &1)
  end

  defp call_http(req) do
    apply(@http_impl, :do_requst, [:http, req])
  end

  @spec request(
          ConfigOption.t(),
          Typespecs.method(),
          Typespecs.api(),
          Typespecs.params(),
          Typespecs.body(),
          Keyword.t()
        ) ::
          {:ok, Http.Response.t()} | {:error, Exception.t()}
  defp request(config, method, api, params, body, opts \\ []) do
    auth = ExWechatpay.Authorization.generate(config, method, api, params, body)

    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", auth}
    ]

    call_http(%Http.Request{
      host: config[:service_host],
      method: method,
      path: api,
      headers: headers,
      body: body,
      params: params,
      opts: opts
    })
  end

  @spec verify(ConfigOption.t(), Typespecs.headers(), Typespecs.body()) :: boolean()
  defp verify(config, headers, body) do
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

  @doc """
  create miniapp payform with a prepay_id

  ## Examples

      %{
        "appid" => "wxefd6b215fca0cacd",
        "nonceStr" => "ODnHX8RwAlw0",
        "package" => "prepay_id=wx28094533993528b1d687203f4f48e20000",
        "paySign" => "xxxx",
        "signType" => "RSA",
        "timeStamp" => 1624844734
      } = miniapp_payform(client, "wx28094533993528b1d687203f4f48e20000")
  """
  @spec miniapp_payform(module(), String.t()) :: Typespecs.dict()
  def miniapp_payform(name, prepay_id) do
    config = get(name)
    ts = Util.timestamp()
    nonce = Util.random_string(12)
    package = "prepay_id=#{prepay_id}"
    signature = sign_miniapp(config, ts, nonce, package)

    %{
      "appid" => config[:appid],
      "timeStamp" => ts,
      "nonceStr" => nonce,
      "package" => package,
      "signType" => "RSA",
      "paySign" => signature
    }
  end

  defp sign_miniapp(config, ts, nonce, package) do
    string_to_sign = "#{config[:appid]}\n#{ts}\n#{nonce}\n#{package}\n"

    string_to_sign
    |> :public_key.sign(:sha256, config[:client_key])
    |> Base.encode64()
  end

  # https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_2.shtml
  @spec decrypt(ConfigOption.t(), Typespecs.dict()) :: binary() | :error
  defp decrypt(config, %{
         "algorithm" => "AEAD_AES_256_GCM",
         "associated_data" => aad,
         "ciphertext" => encoded_ciphertext,
         "nonce" => nonce
       }) do
    with {:ok, ciphertext} <- Base.decode64(encoded_ciphertext) do
      size_total = byte_size(ciphertext)
      ctext_len = size_total - @tag_length
      <<ctext::binary-size(ctext_len), tag::binary-size(@tag_length)>> = ciphertext

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
  获取平台证书
  https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml

  后续用 openssl x509 -in some_cert.pem -pubkey 导出平台公钥

  ## Examples
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
      } = get_certificates(Wechat)
  """
  @spec get_certificates(module()) :: {:ok, Typespecs.dict()} | err_t()
  def get_certificates(name, verify \\ true) do
    config = get(name)

    with {:ok, %{body: body, headers: headers}} <- request(config, :get, "/v3/certificates", %{}, nil) do
      if verify do
        config
        |> verify(headers, body)
        |> if do
          {:ok, %{"data" => data}} =
            Jason.decode(body)

          {:ok, %{"data" => decrypt_certificates(data, config)}}
        else
          {:error, Exception.new("verify_failed", %{"headers" => headers, "body" => body})}
        end
      end
    end
  end

  defp decrypt_certificates(certificates, config) do
    Enum.map(certificates, fn %{"encrypt_certificate" => encrypt_certificate} = x ->
      Map.put(x, "certificate", decrypt(config, encrypt_certificate))
    end)
  end
end
