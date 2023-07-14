defmodule ExWechatpay.Client do
  @moduledoc """
  微信支付客户端behaviour
  """

  alias ExWechatpay.{Error, Http, Util, Request, Typespecs}

  require Logger

  @client_options_schema [
    name: [
      type: :atom,
      doc: "name of this process",
      default: __MODULE__
    ],
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
      doc:
        "APIv3密钥, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay3_2.shtml for more details"
    ],
    wx_pubs: [
      type: {:list, :any},
      default: [{"wechatpay-serial", "pem"}],
      doc:
        "微信平台证书列表, see https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml for more details"
    ],
    client_serial_no: [
      type: :string,
      required: true,
      doc:
        "商户API证书序列号, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml for more details"
    ],
    client_key: [
      type: :string,
      required: true,
      doc:
        "商户API证书私钥, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml for more details"
    ],
    client_cert: [
      type: :string,
      required: true,
      doc:
        "商户API证书, see https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay7_0.shtml for more details"
    ],
    http_client: [
      type: :any,
      doc: "http client instance, default: ExWechatpay.Wechat.Http.Finch.new()",
      required: true
    ]
  ]
  @tag_length 16

  @type t :: %__MODULE__{}
  @type client_options :: keyword(unquote(NimbleOptions.option_typespec(@client_options_schema)))

  defstruct name: __MODULE__,
            appid: "",
            mchid: "",
            service_host: "api.mch.weixin.qq.com",
            notify_url: "",
            apiv3_key: "",
            wx_pubs: [{"wechatpay-serial", nil}],
            client_serial_no: "",
            client_key: nil,
            client_cert: nil,
            http_client: ExWechatpay.Http.Default.new()

  @doc """
  create a new client instance

  ## Options
  #{NimbleOptions.docs(@client_options_schema)}
  """
  @spec new(client_options()) :: t()
  def new(opts) do
    opts =
      opts
      |> NimbleOptions.validate!(@client_options_schema)
      |> Keyword.replace_lazy(:client_key, &Util.load_pem(&1))
      |> Keyword.replace_lazy(:client_cert, &Util.load_pem(&1))
      |> Keyword.replace_lazy(:wx_pubs, fn pairs ->
        pairs
        |> Enum.map(fn {k, v} -> {k, Util.load_pem(v)} end)
      end)

    struct(__MODULE__, opts)
  end

  def child_spec(opts) do
    client = Keyword.fetch!(opts, :client)
    %{id: {__MODULE__, client.name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @spec start_link(Typespecs.opts()) :: Typespecs.on_start()
  def start_link(opts) do
    {client, _opts} = Keyword.pop!(opts, :client)
    Http.start_link(client.http_client)
  end

  @spec request(t(), Request.t(), Typespecs.opts()) ::
          {:ok, Http.Response.t()} | {:error, Error.t()}
  def request(client, req, opts \\ []) do
    with auth <- Request.authorization(client, req),
         headers <- [
           {"Content-Type", "application/json"},
           {"Accept", "application/json"},
           {"Authorization", auth}
         ],
         http_req <-
           Http.Request.new(
             host: client.service_host,
             method: req.method,
             path: req.api,
             headers: headers,
             body: req.body,
             params: req.params,
             opts: opts
           ) do
      Http.do_request(client.http_client, http_req)
    end
  end

  @doc """
  verify the response or notify from wechatpay

  ## Examples

      true = verify(client, [{"header-key", "header-val"}], "notify body")

  """
  @spec verify(t(), Typespecs.headers(), Typespecs.body()) :: boolean()
  def verify(client, headers, body) do
    with headers <- Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end),
         {_, wx_pub} <-
           Enum.find(client.wx_pubs, fn {x, _} -> x == headers["wechatpay-serial"] end),
         ts <- headers["wechatpay-timestamp"],
         nonce <- headers["wechatpay-nonce"],
         string_to_sign <- "#{ts}\n#{nonce}\n#{body}\n",
         encoded_wx_signature <- headers["wechatpay-signature"],
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
  @spec miniapp_payform(t(), String.t()) :: %{String.t() => String.t()}
  def miniapp_payform(client, prepay_id) do
    with ts <- Util.timestamp(),
         nonce <- Util.random_string(12),
         package <- "prepay_id=#{prepay_id}",
         signature <- sign_miniapp(client, ts, nonce, package) do
      %{
        "appid" => client.appid,
        "timeStamp" => ts,
        "nonceStr" => nonce,
        "package" => package,
        "signType" => "RSA",
        "paySign" => signature
      }
    end
  end

  @doc """
  https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_2.shtml
  """
  @spec decrypt(t(), map()) :: binary() | {:error, term()}
  def decrypt(
        client,
        %{
          "algorithm" => "AEAD_AES_256_GCM",
          "associated_data" => aad,
          "ciphertext" => encoded_ciphertext,
          "nonce" => nonce
        }
      ) do
    with {:ok, ciphertext} <- Base.decode64(encoded_ciphertext),
         size_total <- byte_size(ciphertext),
         ctext_len <- size_total - @tag_length,
         <<ctext::binary-size(ctext_len), tag::binary-size(@tag_length)>> <- ciphertext do
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        client.apiv3_key,
        nonce,
        ctext,
        aad,
        tag,
        false
      )
    end
  end

  defp sign_miniapp(client, ts, nonce, package) do
    string_to_sign = "#{client.appid}\n#{ts}\n#{nonce}\n#{package}\n"

    string_to_sign
    |> :public_key.sign(:sha256, client.client_key)
    |> Base.encode64()
  end
end
