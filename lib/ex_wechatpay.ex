defmodule ExWechatpay do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias ExWechatpay.Client

  @wechat_payment_options [
    name: [
      type: :atom,
      doc: "name of this process",
      default: __MODULE__
    ],
    client: [
      type: :any,
      required: true,
      doc: "client instance"
    ]
  ]

  @type t :: %__MODULE__{
          name: atom(),
          client: Client.t()
        }
  @type json_t :: %{bitstring() => any()}
  @type ok_t(ret) :: {:ok, ret}
  @type err_t() :: {:error, ExWechatpay.Error.t()}
  @type options_t :: keyword(unquote(NimbleOptions.option_typespec(@wechat_payment_options)))

  @enforce_keys ~w(name client)a

  defstruct @enforce_keys

  @doc """
  create a new instance of this WechatPayment module

  ## Options
  #{NimbleOptions.docs(@wechat_payment_options)}
  """
  @spec new(options_t()) :: t()
  def new(opts) do
    opts = opts |> NimbleOptions.validate!(@wechat_payment_options)
    struct(__MODULE__, opts)
  end

  def child_spec(opts) do
    wechat = Keyword.fetch!(opts, :wechat)
    %{id: {__MODULE__, wechat.name}, start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(opts) do
    {wechat, opts} = Keyword.pop!(opts, :wechat)

    opts
    |> Keyword.put_new(:client, wechat.client)
    |> Client.start_link()
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
      } = get_certificates(wechat)
  """
  @spec get_certificates(t()) :: ok_t(json_t()) | err_t()
  def get_certificates(wechat, verify \\ true) do
    with {:ok, %{"data" => data}} <-
           Client.request(wechat.client, :get, "/v3/certificates", nil, nil, [], verify?: verify) do
      data =
        data
        |> Enum.map(fn %{"encrypt_certificate" => encrypt_certificate} = x ->
          Map.put(x, "certificate", Client.decrypt(wechat.client, encrypt_certificate))
        end)

      {:ok, %{"data" => data}}
    end
  end

  @doc """
  回执、回调验签
  https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_1.shtml

  ## Examples

      true = verify(wechat, [{"Wechatpay-Serial" => "35CE31ED8F4A50B930FF8D37C51B5ADA03265E72"}], "body")
  """
  @spec verify(t(), Client.headers(), binary()) :: boolean()
  def verify(wechat, headers, body) do
    Client.verify(wechat.client, headers, body)
  end

  @doc """
  https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_1.shtml

  ## Examples

      {:ok, %{"code_url" => "weixin://wxpay/bizpayurl?pr=CvbR9Rmzz"}} =
        ExWechatpay.Wechat.Client.Finch.create_native_transaction(wechat, %{
           "description" => "Image形象店-深圳腾大-QQ公仔",
           "out_trade_no" => "1217752501201407033233368018",
           "notify_url" => "https://www.weixin.qq.com/wxpay/pay.php",
           "amount" => %{
             "total" => 1,
             "currency" => "CNY"
           }
        })

  """
  @spec create_native_transaction(t(), json_t()) :: ok_t(json_t()) | err_t()
  def create_native_transaction(wechat, body) do
    body =
      body
      |> Map.put_new("appid", wechat.client.appid)
      |> Map.put_new("mchid", wechat.client.mchid)
      |> Map.put_new("notify_url", wechat.client.notify_url)

    Client.request(wechat.client, :post, "/v3/pay/transactions/native", body, nil)
  end

  @doc """
  https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_1_1.shtml

  ## Examples

      {:ok, %{"prepay_id" => "wx03173911674781a20cf50feafc02ff0000"}} = create_jsapi_transaction(wechat, %{
        "description" => "Image形象店-深圳腾大-QQ公仔",
        "out_trade_no" => "1217752501201407033233368018",
        "notify_url" => "https://www.weixin.qq.com/wxpay/pay.php",
        "amount" => %{
          "total" => 1,
          "currency" => "CNY"
        },
        "payer" => %{
          "openid" => "oUpF8uMuAJO_M2pxb1Q9zNjWeS6o"
        }
      })
  """
  @spec create_jsapi_transaction(t(), json_t()) :: ok_t(json_t()) | err_t()
  def create_jsapi_transaction(wechat, body) do
    body =
      body
      |> Map.put_new("appid", wechat.client.appid)
      |> Map.put_new("mchid", wechat.client.mchid)
      |> Map.put_new("notify_url", wechat.client.notify_url)

    Client.request(wechat.client, :post, "/v3/pay/transactions/jsapi", body, nil)
  end

  @doc """
  https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_3_1.shtml

  ## Examples

      {:ok, %{"ht_url" => "https://wx.tenpay.com/cgi-bin/..........."}} = create_h5_transaction(wechat, %{
        "description" => "Image形象店-深圳腾大-QQ公仔",
        "out_trade_no" => "1217752501201407033233368018",
        "notify_url" => "https://www.weixin.qq.com/wxpay/pay.php",
        "amount" => %{
          "total" => 1,
          "currency" => "CNY"
        },
        "scene_info" => %{
          "payer_client_ip" => "some ipaddr"
        }
      })
  """
  @spec create_h5_transaction(t(), json_t()) :: ok_t(json_t()) | err_t()
  def create_h5_transaction(wechat, body) do
    body =
      body
      |> Map.put_new("appid", wechat.client.appid)
      |> Map.put_new("mchid", wechat.client.mchid)
      |> Map.put_new("notify_url", wechat.client.notify_url)

    Client.request(wechat.client, :post, "/v3/pay/transactions/h5", body, nil)
  end

  @doc """
  https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_2.shtml

  ## Examples

      {:ok,
       %{
         "amount" => %{
           "currency" => "CNY",
           "payer_currency" => "CNY",
           "payer_total" => 1,
           "total" => 1
         },
         "appid" => "wxefd6b215fca0cacd",
         "attach" => "",
         "bank_type" => "OTHERS",
         "mchid" => "1611120167",
         "out_trade_no" => "testO_1234567890",
         "payer" => %{"openid" => "ohNY75Jw8MlsKuu4cFBbjmK4ZP_w"},
         "promotion_detail" => [],
         "success_time" => "2023-05-31T11:14:40+08:00",
         "trade_state" => "SUCCESS",
         "trade_state_desc" => "支付成功",
         "trade_type" => "NATIVE",
         "transaction_id" => "4200001851202305317391703081"
       }} = ExWechatpay.Wechat.Client.Finch.query_transaction(wechat, :out_trade_no, "1217752501201407033233368018")
  """
  @spec query_transaction(t(), :out_trade_no | :transaction_id, String.t()) ::
          ok_t(json_t()) | err_t()
  def query_transaction(wechat, :out_trade_no, out_trade_no) do
    Client.request(
      wechat.client,
      :get,
      "/v3/pay/transactions/out-trade-no/#{out_trade_no}",
      nil,
      %{"mchid" => wechat.client.mchid}
    )
  end

  def query_transaction(wechat, :transaction_id, transaction_id) do
    Client.request(
      wechat.client,
      :get,
      "/v3/pay/transactions/id/#{transaction_id}",
      nil,
      %{"mchid" => wechat.client.mchid}
    )
  end

  @doc """
  https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_3.shtml

  ## Examples

      :ok = close_transaction(wechat, "1217752501201407033233368018")
  """
  @spec close_transaction(t(), String.t()) :: :ok | err_t()
  def close_transaction(wechat, out_trade_no) do
    Client.request(
      wechat.client,
      :post,
      "/v3/pay/transactions/out-trade-no/#{out_trade_no}/close",
      %{"mchid" => wechat.client.mchid},
      nil
    )
    |> case do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  create a miniapp payform with a jsapi transaction_id

  ## Examples

      {:ok, %{
        "appid" => "wxefd6b215fca0cacd",
        "nonceStr" => "vFPjBwiBRDaf",
        "package" => "prepay_id=testO_1234567890",
        "paySign" => "nxairksHJ3UCp8iHU+F47IIBrV/lmmTjE5rQfOAChtgrtdEo6NX0uhpRfsDEb8eSa7z0c861KWu93fZxOycM8JcQcXEek6e1EMjntDgz3M3+8WhGHm+lxDD7khy9vy9A4iOERxCccXPs0Auep0/a1V5pDHRvrU+5QN0c483mvbS6GwiUUKMwyi78iCap8hezd7ya+YWdChqsbRmz/LpgVf0mmfvzWppAxRCKtCKOU0NNluiKMqdmx9fLwWLEnnJA6wLXvG3zs4EIB/06ibM3OQmcI4nNnFW40jBtuH7yVkH3i+ZhSv0GnUxaLy34Br4cwPpY4FzAuSfOHtC3Nx5/pA==",
        "signType" => "RSA",
        "timeStamp" => 1685676354
      }} = ExWechatpay.Wechat.Client.Finch.miniapp_payform(wechat, "testO_1234567890")
  """
  @spec miniapp_payform(t(), String.t()) :: ok_t(json_t())
  def miniapp_payform(wechat, prepay_id) do
    {:ok, Client.miniapp_payform(wechat.client, prepay_id)}
  end

  @doc """
  https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_3_9.shtml

  ## Examples
    {:ok,
     %{
       "amount" => %{
         "currency" => "CNY",
         "discount_refund" => 0,
         "from" => [],
         "payer_refund" => 1,
         "payer_total" => 1,
         "refund" => 1,
         "refund_fee" => 0,
         "settlement_refund" => 1,
         "settlement_total" => 1,
         "total" => 1
       },
       "channel" => "ORIGINAL",
       "create_time" => "2023-06-05T11:44:56+08:00",
       "funds_account" => "AVAILABLE",
       "out_refund_no" => "refund_E6QEe56ERo",
       "out_trade_no" => "test_QQuuheTjp7",
       "promotion_detail" => [],
       "refund_id" => "50302305912023060535313670012",
       "status" => "PROCESSING",
       "transaction_id" => "4200001869202306052617880791",
       "user_received_account" => "支付用户零钱"
     }} = ExWechatpay.Wechat.Client.Finch.create_refund(wechat, %{
      "amount" => %{"refund" => 1},
      "out_refund_no" => "refund_E6QEe56ERo",
      "out_trade_no" => "test_QQuuheTjp7"
    })

  """
  @spec create_refund(t(), json_t()) :: ok_t(json_t()) | err_t()
  def create_refund(wechat, body) do
    body =
      body
      |> Map.put_new("notify_url", wechat.client.notify_url)

    Client.request(wechat.client, :post, "/v3/refund/domestic/refunds", body, nil)
  end
end
