defmodule ExWechatpay do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @external_resource "README.md"

  defmacro __using__(opts) do
    quote do
      alias ExWechatpay.Core
      alias ExWechatpay.Typespecs

      @type ok_t(ret) :: {:ok, ret}
      @type err_t() :: {:error, ExWechatpay.Exception.t()}

      def init(config) do
        {:ok, config}
      end

      defoverridable init: 1

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(config \\ []) do
        otp_app = unquote(opts[:otp_app])

        {:ok, cfg} =
          otp_app
          |> Application.get_env(__MODULE__, config)
          |> init()

        ExWechatpay.Supervisor.start_link(__MODULE__, cfg)
      end

      defp delegate(method, args), do: apply(Core, method, [__MODULE__ | args])

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
      @spec miniapp_payform(String.t()) :: Typespecs.dict()
      def miniapp_payform(prepay_id), do: delegate(:miniapp_payform, [prepay_id])

      @doc """
      获取平台证书
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml

      后续用 openssl x509 -in some_cert.pem -pubkey 导出平台公钥

      ## Examples
          iex> get_certificates()
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
          }
      """
      @spec get_certificates(boolean()) :: {:ok, Typespecs.dict()} | err_t()
      def get_certificates(verify \\ true), do: delegate(:get_certificates, [verify])

      @doc """
      回执、回调验签
      https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_1.shtml

      ## Examples

          iex> verify([{"Wechatpay-Serial" => "35CE31ED8F4A50B930FF8D37C51B5ADA03265E72"}], "body")
          true
      """
      @spec verify(Typespecs.headers(), Typespecs.body()) :: boolean()
      def verify(headers, body), do: delegate(:verify, [headers, body])

      @doc """
      解密回调信息

      ## Examples
          iex> decrypt(%{
              "algorithm" => "AEAD_AES_256_GCM",
              "ciphertext" => "BoiqBLxeEtXMAmD7pm+...w==",
              "nonce" => "2862867afb33",
              "associated_data" => "transaction"
            })
          {:ok, "1217752501201407033233368018"}
      """
      @spec decrypt(Typespecs.dict()) :: {:ok, binary()} | err_t()
      def decrypt(encrypted_form), do: delegate(:decrypt, [encrypted_form])

      @doc """
      Native下单API
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_1.shtml

      ## Examples

          iex> create_native_transaction(%{
               "description" => "Image形象店-深圳腾大-QQ公仔",
               "out_trade_no" => "1217752501201407033233368018",
               "notify_url" => "https://www.weixin.qq.com/wxpay/pay.php",
               "amount" => %{
                 "total" => 1,
                 "currency" => "CNY"
               }
            })
          {:ok, %{"code_url" => "weixin://wxpay/bizpayurl?pr=CvbR9Rmzz"}}

      """
      @spec create_native_transaction(Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
      def create_native_transaction(args), do: delegate(:create_native_transaction, [args])

      @doc """
      JSAPI下单
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_1_1.shtml

      ## Examples

          iex> create_jsapi_transaction(%{
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
          {:ok, %{"prepay_id" => "wx03173911674781a20cf50feafc02ff0000"}}
      """
      @spec create_jsapi_transaction(Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
      def create_jsapi_transaction(args), do: delegate(:create_jsapi_transaction, [args])

      @doc """
      H5下单API
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_3_1.shtml

      ## Examples

          iex> create_h5_transaction(%{
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
          {:ok, %{"ht_url" => "https://wx.tenpay.com/cgi-bin/..........."}}
      """

      @spec create_h5_transaction(Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
      def create_h5_transaction(args), do: delegate(:create_h5_transaction, [args])

      @doc """
      查询订单API
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_2.shtml

      ## Examples
         iex> query_transaction_by_out_trade_no("testO_1234567890")
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
          }}
      """
      @spec query_transaction_by_out_trade_no(binary()) :: ok_t(Typespecs.dict()) | err_t()
      def query_transaction_by_out_trade_no(out_trade_no),
        do: delegate(:query_transaction_by_out_trade_no, [out_trade_no])

      @doc """
      查询订单API
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_2.shtml

      ## Examples
         iex> query_transaction_by_transaction_id("4200001851202305317391703081")
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
          }}
      """
      @spec query_transaction_by_transaction_id(binary()) :: ok_t(Typespecs.dict()) | err_t()
      def query_transaction_by_transaction_id(transaction_id),
        do: delegate(:query_transaction_by_transaction_id, [transaction_id])

      @doc """
      关闭订单API
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_3.shtml

      ## Examples
          iex> close_transaction("1217752501201407033233368018")
          :ok
      """
      @spec close_transaction(binary()) :: :ok | err_t()
      def close_transaction(out_trade_no), do: delegate(:close_transaction, [out_trade_no])

      @doc """
      申请退款API
      https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_3_9.shtml

      ## Examples
          iex> create_refund(%{
            "amount" => %{"refund" => 1},
            "out_refund_no" => "refund_E6QEe56ERo",
            "out_trade_no" => "test_QQuuheTjp7"
          })
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
           }}
      """
      @spec create_refund(Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
      def create_refund(args), do: delegate(:create_refund, [args])
    end
  end
end
