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

  def start_link({name, http_name, config}) do
    config =
      config
      |> ConfigOption.validate!()
      |> Keyword.replace_lazy(:client_key, &Util.load_pem(&1))
      |> Keyword.replace_lazy(:client_cert, &Util.load_pem(&1))
      |> Keyword.replace_lazy(:wx_pubs, fn pairs ->
        Enum.map(pairs, fn {k, v} -> {k, Util.load_pem(v)} end)
      end)
      |> Keyword.put(:http_name, http_name)

    Agent.start_link(fn -> config end, name: name)
  end

  def get(name) do
    Agent.get(name, & &1)
  end

  defp call_http(name, req) do
    apply(@http_impl, :do_request, [name, req])
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

    call_http(config[:http_name], %Http.Request{
      host: config[:service_host],
      method: method,
      path: api,
      headers: headers,
      body: body,
      params: params,
      opts: opts
    })
  end

  @spec do_verify(ConfigOption.t(), Typespecs.headers(), Typespecs.body()) :: boolean()
  defp do_verify(config, headers, body) do
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
  @spec do_decrypt(ConfigOption.t(), Typespecs.dict()) :: binary() | :error
  defp do_decrypt(config, %{
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

  @spec get_certificates(module()) :: {:ok, Typespecs.dict()} | err_t()
  def get_certificates(name, verify \\ true) do
    config = get(name)

    with {:ok, %Http.Response{body: body, headers: headers}} <- request(config, :get, "/v3/certificates", %{}, nil) do
      if verify do
        config
        |> do_verify(headers, body)
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
      Map.put(x, "certificate", do_decrypt(config, encrypt_certificate))
    end)
  end

  @spec verify(module(), Typespecs.headers(), Typespecs.body()) :: boolean()
  def verify(name, headers, body) do
    name
    |> get()
    |> do_verify(headers, body)
  end

  @spec decrypt(module(), Typespecs.dict()) :: {:ok, binary()} | err_t()
  def decrypt(name, encrypted_form) do
    name
    |> get()
    |> do_decrypt(encrypted_form)
    |> case do
      :error -> {:error, Exception.new("decrypt_failed", %{"encrypted_form" => encrypted_form})}
      ret -> {:ok, ret}
    end
  end

  @spec extend_args(ConfigOption.t(), Typespecs.dict()) :: {:ok, binary()}
  defp extend_args(config, args) do
    args
    |> Map.put_new("appid", config[:appid])
    |> Map.put_new("mchid", config[:mchid])
    |> Map.put_new("notify_url", config[:notify_url])
    |> Jason.encode()
  end

  @spec verify_resp(ConfigOption.t(), Http.Response.t()) :: ok_t(Typespecs.dict()) | err_t()
  defp verify_resp(config, resp) do
    %Http.Response{headers: headers, body: body} = resp

    config
    |> do_verify(headers, body)
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

  @spec create_native_transaction(module(), Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
  def create_native_transaction(name, args) do
    config = get(name)
    {:ok, body} = extend_args(config, args)

    with {:ok, resp} <- request(config, :post, "/v3/pay/transactions/native", %{}, body) do
      verify_resp(config, resp)
    end
  end
end
