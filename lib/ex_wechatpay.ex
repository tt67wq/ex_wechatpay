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

      @doc """
      获取当前配置

      获取当前微信支付 SDK 的完整配置信息，包括商户信息、证书信息、API 密钥等。

      ## 返回值
         * `Typespecs.config_t()` - 当前配置，包含以下主要字段：
           * `appid` - 应用 ID
           * `mchid` - 商户号
           * `service_host` - 服务主机地址
           * `notify_url` - 回调通知地址
           * `apiv3_key` - API v3 密钥
           * `wx_pubs` - 微信平台证书列表
           * `client_serial_no` - 商户 API 证书序列号
           * `client_key` - 商户 API 证书私钥
           * `client_cert` - 商户 API 证书
           * `timeout` - 请求超时时间
           * `retry` - 是否启用重试
           * `retry_times` - 重试次数
           * `retry_delay` - 重试延迟
           * `log_level` - 日志级别

      ## 示例
          iex> get_config()
          [
            appid: "wx1234567890abcdef",
            mchid: "1230000109",
            service_host: "api.mch.weixin.qq.com",
            notify_url: "https://example.com/notify",
            # 其他配置...
          ]
      """
      def get_config do
        ExWechatpay.Config.Helper.get_config(__MODULE__)
      end

      @doc """
      更新配置

      动态更新微信支付 SDK 的配置，可用于在运行时调整参数，如超时设置、日志级别等。

      ## 参数
         * `updates` - 要更新的配置，可以是部分配置，未指定的配置项保持不变

      ## 返回值
         * `{:ok, new_config}` - 更新成功，返回更新后的完整配置
         * `{:error, error}` - 更新失败，返回错误信息

      ## 示例
          iex> update_config(timeout: 10000, log_level: :debug)
          {:ok, [
            appid: "wx1234567890abcdef",
            mchid: "1230000109",
            timeout: 10000,
            log_level: :debug,
            # 其他配置...
          ]}
      """
      def update_config(updates) do
        ExWechatpay.Config.Helper.update_config(__MODULE__, updates)
      end

      @doc """
      更新证书

      从微信支付服务器获取最新的平台证书并更新配置。

      微信支付的平台证书会定期更新，此函数可以手动触发证书更新，确保验签功能正常工作。
      平台证书主要用于验证微信支付的回调通知。

      ## 返回值
         * `{:ok, new_config}` - 更新成功，返回更新后的配置
         * `{:error, error}` - 更新失败，返回错误信息

      ## 示例
          iex> update_certificates()
          {:ok, [
            # 更新后的完整配置，包含新的证书信息
            wx_pubs: [{"serial_no_1", "cert_content_1"}, ...]
          ]}
      """
      def update_certificates do
        ExWechatpay.Config.Helper.update_certificates(__MODULE__)
      end

      @doc """
      启用自动更新证书

      设置定期自动从微信支付服务器获取并更新平台证书。

      由于微信支付平台证书会定期更新，启用此功能可确保系统始终使用最新的证书，
      避免因证书过期导致的验签失败问题。

      ## 参数
         * `interval` - 更新间隔时间（毫秒），默认为 1 天（86400000 毫秒）

      ## 返回值
         * `:ok` - 成功启用自动更新

      ## 示例
          # 启用自动更新，每天更新一次
          iex> enable_auto_update_certificates()
          :ok

          # 启用自动更新，每 12 小时更新一次
          iex> enable_auto_update_certificates(60_000 * 60 * 12)
          :ok
      """
      def enable_auto_update_certificates(interval \\ 60_000 * 60 * 24) do
        ExWechatpay.Config.Helper.enable_auto_update_certificates(__MODULE__, interval)
      end

      @doc """
      禁用自动更新证书

      停止自动更新微信支付平台证书的定时任务。

      禁用后，需要手动调用 `update_certificates/0` 来更新证书，
      或者在需要时重新启用自动更新功能。

      ## 返回值
         * `:ok` - 成功禁用自动更新

      ## 示例
          iex> disable_auto_update_certificates()
          :ok
      """
      def disable_auto_update_certificates do
        ExWechatpay.Config.Helper.disable_auto_update_certificates(__MODULE__)
      end

      defp delegate(method, args), do: apply(Core, method, [__MODULE__ | args])

      @doc """
      生成小程序支付表单

      根据预支付交易会话标识（prepay_id）生成用于小程序支付的参数。

      小程序支付需要将此函数返回的参数传递给小程序前端的 `wx.requestPayment` 方法。

      ## 参数
         * `prepay_id` - 预支付交易会话标识，通过 `create_jsapi_transaction/1` 获取

      ## 返回值
         * `%{String.t() => String.t()}` - 小程序支付所需的参数

      ## 示例
          iex> miniapp_payform("wx28094533993528b1d687203f4f48e20000")
          %{
            "appId" => "wxefd6b215fca0cacd",
            "nonceStr" => "ODnHX8RwAlw0",
            "package" => "prepay_id=wx28094533993528b1d687203f4f48e20000",
            "paySign" => "xxxx", # 实际值为签名字符串
            "signType" => "RSA",
            "timeStamp" => "1624844734"
          }
      """
      @spec miniapp_payform(String.t()) :: %{required(String.t()) => String.t()}
      def miniapp_payform(prepay_id), do: delegate(:miniapp_payform, [prepay_id])

      @doc """
      获取微信支付平台证书

      从微信支付服务器获取平台证书列表，包括证书序列号、有效期和证书内容。

      此接口用于获取微信支付平台证书，主要用于验证微信支付的回调通知。
      平台证书会定期更新，建议定期调用此接口获取最新证书，或使用 `enable_auto_update_certificates/1` 启用自动更新。

      ## 参数
         * `verify` - 是否验证证书签名，默认为 `true`

      ## 返回值
         * `{:ok, %{"data" => [Typespecs.wx_cert()]}}` - 获取成功，返回证书列表
         * `{:error, Exception.t()}` - 获取失败，返回错误信息

      ## 示例
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

      ## 参考
      [微信支付-获取平台证书](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/wechatpay5_1.shtml)
      """
      @spec get_certificates(boolean()) :: Typespecs.result_t([Typespecs.wx_cert()])
      def get_certificates(verify \\ true), do: delegate(:get_certificates, [verify])

      @doc """
      验证微信支付通知或响应签名

      验证微信支付回调通知或 API 响应的签名是否有效，确保数据未被篡改。

      此函数用于验证微信支付的回调通知或 API 响应的签名，以确保数据的真实性和完整性。
      对于回调通知，建议始终进行签名验证。

      ## 参数
         * `headers` - HTTP 请求/响应头，需包含签名相关字段（Wechatpay-Signature, Wechatpay-Serial 等）
         * `body` - HTTP 请求/响应体

      ## 返回值
         * `true` - 验证通过
         * `false` - 验证失败

      ## 示例
          iex> headers = [
          ...>   {"Wechatpay-Signature", "签名值"},
          ...>   {"Wechatpay-Serial", "35CE31ED8F4A50B930FF8D37C51B5ADA03265E72"},
          ...>   {"Wechatpay-Timestamp", "1626343588"},
          ...>   {"Wechatpay-Nonce", "随机字符串"}
          ...> ]
          iex> body = "{\"transaction_id\":\"4200001285202103303271489573\"}"
          iex> verify(headers, body)
          true

      ## 参考
      [微信支付-验证签名](https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_1.shtml)
      """
      @spec verify(Typespecs.headers(), Typespecs.body()) :: boolean()
      def verify(headers, body), do: delegate(:verify, [headers, body])

      @doc """
      解密微信支付加密数据

      解密微信支付回调通知中的加密数据，如敏感信息（退款通知、支付成功通知等）。

      微信支付的回调通知中，敏感信息会被加密。使用此函数可以解密这些数据，
      解密使用的密钥为配置中的 `apiv3_key`。

      ## 参数
         * `encrypted_form` - 加密数据，包含加密算法、密文、关联数据和随机串

      ## 返回值
         * `{:ok, binary()}` - 解密成功，返回解密后的数据
         * `{:error, Exception.t()}` - 解密失败，返回错误信息

      ## 示例
          iex> encrypted_data = %{
          ...>   "algorithm" => "AEAD_AES_256_GCM",
          ...>   "ciphertext" => "加密后的密文...",
          ...>   "nonce" => "随机串",
          ...>   "associated_data" => "关联数据"
          ...> }
          iex> decrypt(encrypted_data)
          {:ok, "{\"transaction_id\":\"4200001285202103303271489573\"}"}
      """
      @spec decrypt(Typespecs.encrypted_resource()) :: Typespecs.result_t(binary())
      def decrypt(encrypted_form), do: delegate(:decrypt, [encrypted_form])

      @doc """
      创建 Native 支付交易（扫码支付）

      创建微信支付的 Native 支付（扫码支付）交易，生成支付二维码链接。

      Native 支付适用于 PC 网站、实体店单品或订单支付、媒体广告支付等场景。
      用户使用微信客户端扫描商户生成的二维码完成支付。

      ## 参数
         * `args` - 交易参数，符合 `Typespecs.native_transaction_req()` 类型
           * `description` - 商品描述
           * `out_trade_no` - 商户订单号，需保证唯一性
           * `notify_url` - 通知地址（可选，默认使用配置中的值）
           * `amount` - 金额信息
             * `total` - 总金额，单位为分
             * `currency` - 货币类型，默认为 CNY
           * `goods_tag` - 订单优惠标记（可选）
           * `scene_info` - 支付场景描述（可选）
           * `settle_info` - 结算信息（可选）

      ## 返回值
         * `{:ok, Typespecs.native_transaction_resp()}` - 创建成功，返回支付二维码链接
           * `code_url` - 二维码链接，商户可将该链接生成二维码图片展示给用户
         * `{:error, Exception.t()}` - 创建失败，返回错误信息

      ## 示例
          iex> create_native_transaction(%{
          ...>   "description" => "Image形象店-深圳腾大-QQ公仔",
          ...>   "out_trade_no" => "1217752501201407033233368018",
          ...>   "amount" => %{
          ...>     "total" => 1,
          ...>     "currency" => "CNY"
          ...>   }
          ...> })
          {:ok, %{"code_url" => "weixin://wxpay/bizpayurl?pr=CvbR9Rmzz"}}

      ## 参考
      [微信支付-Native支付](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_1.shtml)
      """
      @spec create_native_transaction(Typespecs.native_transaction_req()) ::
              Typespecs.result_t(Typespecs.native_transaction_resp())
      def create_native_transaction(args), do: delegate(:create_native_transaction, [args])

      @doc """
      创建 JSAPI 支付交易（公众号/小程序支付）

      创建微信支付的 JSAPI 支付交易，用于微信公众号或小程序内的支付场景。

      JSAPI 支付适用于微信公众号、微信小程序内的支付场景。
      获取到预支付交易会话标识后，需要使用 `miniapp_payform/1` 生成支付参数，传递给前端调用支付接口。

      ## 参数
         * `args` - 交易参数，符合 `Typespecs.jsapi_transaction_req()` 类型
           * `description` - 商品描述
           * `out_trade_no` - 商户订单号，需保证唯一性
           * `notify_url` - 通知地址（可选，默认使用配置中的值）
           * `amount` - 金额信息
             * `total` - 总金额，单位为分
             * `currency` - 货币类型，默认为 CNY
           * `payer` - 支付者信息
             * `openid` - 用户在商户 appid 下的唯一标识
           * `goods_tag` - 订单优惠标记（可选）
           * `scene_info` - 支付场景描述（可选）
           * `settle_info` - 结算信息（可选）

      ## 返回值
         * `{:ok, Typespecs.jsapi_transaction_resp()}` - 创建成功，返回预支付交易会话标识
           * `prepay_id` - 预支付交易会话标识，可用于生成支付参数
         * `{:error, Exception.t()}` - 创建失败，返回错误信息

      ## 示例
          iex> create_jsapi_transaction(%{
          ...>   "description" => "Image形象店-深圳腾大-QQ公仔",
          ...>   "out_trade_no" => "1217752501201407033233368018",
          ...>   "amount" => %{
          ...>     "total" => 1,
          ...>     "currency" => "CNY"
          ...>   },
          ...>   "payer" => %{
          ...>     "openid" => "oUpF8uMuAJO_M2pxb1Q9zNjWeS6o"
          ...>   }
          ...> })
          {:ok, %{"prepay_id" => "wx03173911674781a20cf50feafc02ff0000"}}

      ## 参考
      [微信支付-JSAPI支付](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_1_1.shtml)
      """
      @spec create_jsapi_transaction(Typespecs.jsapi_transaction_req()) ::
              Typespecs.result_t(Typespecs.jsapi_transaction_resp())
      def create_jsapi_transaction(args), do: delegate(:create_jsapi_transaction, [args])

      @doc """
      创建 H5 支付交易（H5 网页支付）

      创建微信支付的 H5 支付交易，用于移动端网页内的支付场景。

      H5 支付适用于移动端网页应用，用户在微信外部的手机浏览器中访问商户 H5 页面时可以调用微信支付完成付款。
      商户需要将 H5 支付链接 `h5_url` 发送给用户，用户点击后会跳转到微信支付页面。

      ## 参数
         * `args` - 交易参数，符合 `Typespecs.h5_transaction_req()` 类型
           * `description` - 商品描述
           * `out_trade_no` - 商户订单号，需保证唯一性
           * `notify_url` - 通知地址（可选，默认使用配置中的值）
           * `amount` - 金额信息
             * `total` - 总金额，单位为分
             * `currency` - 货币类型，默认为 CNY
           * `scene_info` - 支付场景描述（必填）
             * `payer_client_ip` - 用户终端 IP
             * `device_id` - 商户端设备号（可选）
             * `store_info` - 商户门店信息（可选）
           * `goods_tag` - 订单优惠标记（可选）
           * `settle_info` - 结算信息（可选）

      ## 返回值
         * `{:ok, Typespecs.h5_transaction_resp()}` - 创建成功，返回支付跳转链接
           * `h5_url` - 支付跳转链接，用户点击后会跳转到微信支付页面
         * `{:error, Exception.t()}` - 创建失败，返回错误信息

      ## 示例
          iex> create_h5_transaction(%{
          ...>   "description" => "Image形象店-深圳腾大-QQ公仔",
          ...>   "out_trade_no" => "1217752501201407033233368018",
          ...>   "amount" => %{
          ...>     "total" => 1,
          ...>     "currency" => "CNY"
          ...>   },
          ...>   "scene_info" => %{
          ...>     "payer_client_ip" => "127.0.0.1",
          ...>     "device_id" => "device_id_123"
          ...>   }
          ...> })
          {:ok, %{"h5_url" => "https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?prepay_id=..."}}

      ## 参考
      [微信支付-H5支付](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_3_1.shtml)
      """
      @spec create_h5_transaction(Typespecs.h5_transaction_req()) :: Typespecs.result_t(Typespecs.h5_transaction_resp())
      def create_h5_transaction(args), do: delegate(:create_h5_transaction, [args])

      @doc """
      通过商户订单号查询交易

      使用商户订单号查询微信支付交易详情，可获取交易状态、支付金额、支付时间等信息。

      适用于商户需要主动查询交易状态的场景，如：
      - 未收到支付通知时，主动查询交易状态
      - 核对/对账时，确认交易信息
      - 用户查询订单信息时，展示交易状态

      ## 参数
         * `out_trade_no` - 商户订单号，商户系统内部订单号

      ## 返回值
         * `{:ok, Typespecs.transaction_query_resp()}` - 查询成功，返回交易详情
           * `transaction_id` - 微信支付交易订单号
           * `out_trade_no` - 商户订单号
           * `trade_state` - 交易状态
           * `trade_state_desc` - 交易状态描述
           * `amount` - 金额信息
           * `payer` - 支付者信息
           * 等其他交易信息
         * `{:error, Exception.t()}` - 查询失败，返回错误信息

      ## 示例
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

      ## 参考
      [微信支付-查询订单](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_2.shtml)
      """
      @spec query_transaction_by_out_trade_no(String.t()) :: Typespecs.result_t(Typespecs.transaction_query_resp())
      def query_transaction_by_out_trade_no(out_trade_no),
        do: delegate(:query_transaction_by_out_trade_no, [out_trade_no])

      @doc """
      通过微信支付订单号查询交易

      使用微信支付订单号查询交易详情，可获取交易状态、支付金额、支付时间等信息。

      适用于商户需要通过微信支付订单号查询交易状态的场景，如：
      - 支付通知中获取到微信支付订单号后，确认交易信息
      - 核对/对账时，通过微信支付订单号查询交易详情

      ## 参数
         * `transaction_id` - 微信支付订单号

      ## 返回值
         * `{:ok, Typespecs.transaction_query_resp()}` - 查询成功，返回交易详情
           * `transaction_id` - 微信支付交易订单号
           * `out_trade_no` - 商户订单号
           * `trade_state` - 交易状态
           * `trade_state_desc` - 交易状态描述
           * `amount` - 金额信息
           * `payer` - 支付者信息
           * 等其他交易信息
         * `{:error, Exception.t()}` - 查询失败，返回错误信息

      ## 示例
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

      ## 参考
      [微信支付-查询订单](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_2.shtml)
      """
      @spec query_transaction_by_transaction_id(String.t()) :: Typespecs.result_t(Typespecs.transaction_query_resp())
      def query_transaction_by_transaction_id(transaction_id),
        do: delegate(:query_transaction_by_transaction_id, [transaction_id])

      @doc """
      关闭订单

      关闭商户创建的未支付交易，避免用户继续支付。

      适用于以下场景：
      - 商户订单支付超时，主动关闭交易
      - 用户主动取消订单，关闭相应的微信支付交易
      - 订单已过期，关闭交易避免用户继续支付

      ## 参数
         * `out_trade_no` - 商户订单号，需与创建交易时的订单号一致

      ## 返回值
         * `:ok` - 关闭成功
         * `{:error, Exception.t()}` - 关闭失败，返回错误信息

      ## 示例
          iex> close_transaction("1217752501201407033233368018")
          :ok

      ## 参考
      [微信支付-关闭订单](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_3.shtml)
      """
      @spec close_transaction(String.t()) :: :ok | Typespecs.err_t()
      def close_transaction(out_trade_no), do: delegate(:close_transaction, [out_trade_no])

      @doc """
      申请退款

      对已支付的订单发起退款申请，支持全额或部分退款。

      适用于以下场景：
      - 用户取消已支付订单，需要退款
      - 订单异常，需要全额退款
      - 部分商品缺货或用户部分退货，需要部分退款

      ## 参数
         * `args` - 退款参数，符合 `Typespecs.refund_req()` 类型
           * `out_refund_no` - 商户退款单号，需保证唯一性
           * `out_trade_no` - 商户订单号（与 transaction_id 二选一）
           * `transaction_id` - 微信支付订单号（与 out_trade_no 二选一）
           * `amount` - 退款金额信息
             * `refund` - 退款金额，单位为分
             * `total` - 原订单金额，单位为分
             * `currency` - 货币类型，默认为 CNY
           * `reason` - 退款原因（可选）
           * `notify_url` - 退款结果通知地址（可选）
           * `funds_account` - 退款资金来源（可选）

      ## 返回值
         * `{:ok, Typespecs.refund_resp()}` - 申请成功，返回退款信息
           * `refund_id` - 微信支付退款号
           * `out_refund_no` - 商户退款单号
           * `status` - 退款状态
           * `amount` - 金额信息
           * 等其他退款信息
         * `{:error, Exception.t()}` - 申请失败，返回错误信息

      ## 示例
          iex> create_refund(%{
          ...>   "out_refund_no" => "refund_E6QEe56ERo",
          ...>   "out_trade_no" => "test_QQuuheTjp7",
          ...>   "amount" => %{
          ...>     "refund" => 1,
          ...>     "total" => 1,
          ...>     "currency" => "CNY"
          ...>   }
          ...> })
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

      ## 参考
      [微信支付-申请退款](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_9.shtml)
      """
      @spec create_refund(Typespecs.refund_req()) :: Typespecs.result_t(Typespecs.refund_resp())
      def create_refund(args), do: delegate(:create_refund, [args])

      @doc """
      查询退款

      通过商户退款单号查询退款详情，可获取退款状态、退款金额、退款时间等信息。

      适用于以下场景：
      - 未收到退款通知时，主动查询退款状态
      - 核对/对账时，确认退款信息
      - 用户查询退款进度时，展示退款状态

      ## 参数
         * `out_refund_no` - 商户退款单号，需与申请退款时的退款单号一致

      ## 返回值
         * `{:ok, Typespecs.refund_query_resp()}` - 查询成功，返回退款详情
           * `refund_id` - 微信支付退款号
           * `out_refund_no` - 商户退款单号
           * `status` - 退款状态
           * `amount` - 金额信息
           * 等其他退款信息
         * `{:error, Exception.t()}` - 查询失败，返回错误信息

      ## 示例
          iex> query_refund("refund_E6QEe56ERo")
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
             "status" => "SUCCESS",
             "success_time" => "2023-06-05T11:45:10+08:00",
             "transaction_id" => "4200001869202306052617880791",
             "user_received_account" => "支付用户零钱"
           }}

      ## 参考
      [微信支付-查询退款](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_10.shtml)
      """
      @spec query_refund(String.t()) :: Typespecs.result_t(Typespecs.refund_query_resp())
      def query_refund(out_refund_no), do: delegate(:query_refund, [out_refund_no])

      @doc """
      处理退款通知

      处理微信支付发送的退款结果通知，验证签名并解密通知数据。

      微信支付会在退款状态发生变化时，通过退款通知 URL 通知商户。
      商户需要接收并处理这些通知，以便及时获取退款结果。

      ## 参数
         * `headers` - HTTP 请求头，包含签名相关信息
         * `body` - HTTP 请求体，包含加密的通知数据

      ## 返回值
         * `{:ok, Typespecs.payment_notification()}` - 处理成功，返回解析后的通知数据
           * `id` - 通知 ID
           * `create_time` - 通知创建时间
           * `event_type` - 通知类型
           * `resource_type` - 资源类型
           * `resource` - 解密后的资源数据，包含退款详情
           * `summary` - 通知简要说明
         * `{:error, Exception.t()}` - 处理失败，返回错误信息

      ## 示例
          iex> headers = [
          ...>   {"Wechatpay-Signature", "签名值"},
          ...>   {"Wechatpay-Serial", "证书序列号"},
          ...>   {"Wechatpay-Timestamp", "时间戳"},
          ...>   {"Wechatpay-Nonce", "随机字符串"}
          ...> ]
          iex> body = "{\"id\":\"EV-2018022511223320873\",\"create_time\":\"2018-06-08T10:34:56+08:00\",\"resource_type\":\"encrypt-resource\",\"event_type\":\"REFUND.SUCCESS\",\"summary\":\"退款成功\",\"resource\":{\"algorithm\":\"AEAD_AES_256_GCM\",\"ciphertext\":\"...\",\"nonce\":\"...\",\"associated_data\":\"refund\"}}"
          iex> handle_refund_notification(headers, body)
          {:ok,
           %{
             "id" => "EV-2018022511223320873",
             "create_time" => "2018-06-08T10:34:56+08:00",
             "event_type" => "REFUND.SUCCESS",
             "resource_type" => "encrypt-resource",
             "summary" => "退款成功",
             "resource" => %{
               # 解密后的退款详情
               "refund_id" => "50000000382019052709732678859",
               "out_refund_no" => "refund_E6QEe56ERo",
               "status" => "SUCCESS",
               # 其他退款信息...
             }
           }}

      ## 参考
      [微信支付-退款结果通知](https://pay.weixin.qq.com/wiki/doc/apiv3/apis/chapter3_4_11.shtml)
      """
      @spec handle_refund_notification(Typespecs.headers(), Typespecs.body()) ::
              Typespecs.result_t(Typespecs.payment_notification())
      def handle_refund_notification(headers, body), do: delegate(:handle_refund_notification, [headers, body])
    end
  end
end
