defmodule ExWechatpay.Typespecs do
  @moduledoc """
  类型定义模块

  该模块定义了 ExWechatpay 中使用的各种类型，为代码提供了更精确的类型规范。
  包括基础类型、请求/响应类型、配置类型、错误类型等，以支持更好的类型检查和文档生成。
  """

  alias ExWechatpay.Config.Schema
  alias ExWechatpay.Exception

  #
  # 基础类型
  #

  @typedoc "进程名称，可以是原子、全局名称或通过注册表访问的名称"
  @type name :: atom() | {:global, term()} | {:via, module(), term()}

  @typedoc "选项列表，通常用于配置和参数传递"
  @type opts :: keyword()

  @typedoc "HTTP 请求方法"
  @type method :: :get | :post | :head | :patch | :delete | :options | :put

  @typedoc "API 路径"
  @type api :: String.t()

  @typedoc "HTTP 请求头列表"
  @type headers :: [{String.t(), String.t()}]

  @typedoc "HTTP 请求体"
  @type body :: binary() | nil

  @typedoc "HTTP 查询参数"
  @type params :: %{String.t() => binary()} | nil

  @typedoc "HTTP 状态码"
  @type http_status :: non_neg_integer()

  @typedoc "GenServer 启动返回值"
  @type on_start ::
          {:ok, pid()}
          | :ignore
          | {:error, {:already_started, pid()} | term()}

  @typedoc "通用字典类型，用于表示各种数据结构"
  @type dict :: %{String.t() => any()}

  #
  # 响应类型
  #

  @typedoc "成功返回类型"
  @type ok_t(ret) :: {:ok, ret}

  @typedoc "错误返回类型"
  @type err_t() :: {:error, Exception.t()}

  @typedoc "通用操作结果类型"
  @type result_t(ret) :: ok_t(ret) | err_t()

  #
  # 配置类型
  #

  @typedoc "配置类型，使用 Schema 定义的类型"
  @type config_t :: Schema.t()

  #
  # 微信支付特定类型
  #

  @typedoc """
  微信支付签名信息

  * `timestamp` - 签名时间戳
  * `nonce_str` - 随机字符串
  * `signature` - 签名字符串
  """
  @type signature_info :: %{
          timestamp: String.t(),
          nonce_str: String.t(),
          signature: String.t()
        }

  @typedoc """
  微信平台证书信息

  * `serial_no` - 证书序列号
  * `effective_time` - 证书生效时间
  * `expire_time` - 证书过期时间
  * `cert` - 证书内容
  """
  @type wx_cert :: %{
          serial_no: String.t(),
          effective_time: String.t(),
          expire_time: String.t(),
          cert: term()
        }

  #
  # 交易相关类型
  #

  @typedoc """
  交易金额信息

  * `total` - 总金额（单位：分）
  * `currency` - 货币类型，默认为 CNY（人民币）
  """
  @type amount :: %{
          total: non_neg_integer(),
          currency: String.t()
        }

  @typedoc """
  订单优惠标记，用于指定订单支持的优惠类型
  """
  @type goods_tag :: String.t()

  @typedoc """
  支付场景描述

  * `payer_client_ip` - 用户客户端 IP
  * `device_id` - 设备 ID
  * `store_info` - 商户门店信息
  """
  @type scene_info :: %{
          payer_client_ip: String.t(),
          device_id: String.t(),
          store_info: store_info() | nil
        }

  @typedoc """
  商户门店信息

  * `id` - 门店 ID
  * `name` - 门店名称
  * `area_code` - 门店行政区划码
  * `address` - 门店详细地址
  """
  @type store_info :: %{
          id: String.t(),
          name: String.t(),
          area_code: String.t(),
          address: String.t()
        }

  @typedoc """
  支付者信息

  * `openid` - 用户在商户 appid 下的唯一标识
  """
  @type payer :: %{
          openid: String.t()
        }

  @typedoc """
  商品信息

  * `cost_price` - 商品单价（单位：分）
  * `quantity` - 商品数量
  * `goods_name` - 商品名称
  * `goods_detail` - 商品详情
  """
  @type goods :: %{
          cost_price: non_neg_integer(),
          quantity: non_neg_integer(),
          goods_name: String.t(),
          goods_detail: String.t() | nil
        }

  @typedoc """
  结算信息

  * `profit_sharing` - 是否分账
  """
  @type settle_info :: %{
          profit_sharing: boolean()
        }

  #
  # 交易请求类型
  #

  @typedoc """
  JSAPI 支付请求参数

  * `description` - 商品描述
  * `out_trade_no` - 商户订单号
  * `notify_url` - 通知地址（可选，默认使用配置中的通知地址）
  * `amount` - 订单金额信息
  * `payer` - 支付者信息
  * `goods_tag` - 订单优惠标记（可选）
  * `scene_info` - 支付场景描述（可选）
  * `settle_info` - 结算信息（可选）
  """
  @type jsapi_transaction_req :: %{
          description: String.t(),
          out_trade_no: String.t(),
          notify_url: String.t() | nil,
          amount: amount(),
          payer: payer(),
          goods_tag: goods_tag() | nil,
          scene_info: scene_info() | nil,
          settle_info: settle_info() | nil
        }

  @typedoc """
  Native 支付请求参数（二维码支付）

  * `description` - 商品描述
  * `out_trade_no` - 商户订单号
  * `notify_url` - 通知地址（可选，默认使用配置中的通知地址）
  * `amount` - 订单金额信息
  * `goods_tag` - 订单优惠标记（可选）
  * `scene_info` - 支付场景描述（可选）
  * `settle_info` - 结算信息（可选）
  """
  @type native_transaction_req :: %{
          description: String.t(),
          out_trade_no: String.t(),
          notify_url: String.t() | nil,
          amount: amount(),
          goods_tag: goods_tag() | nil,
          scene_info: scene_info() | nil,
          settle_info: settle_info() | nil
        }

  @typedoc """
  H5 支付请求参数

  * `description` - 商品描述
  * `out_trade_no` - 商户订单号
  * `notify_url` - 通知地址（可选，默认使用配置中的通知地址）
  * `amount` - 订单金额信息
  * `scene_info` - 支付场景描述（必填）
  * `goods_tag` - 订单优惠标记（可选）
  * `settle_info` - 结算信息（可选）
  """
  @type h5_transaction_req :: %{
          description: String.t(),
          out_trade_no: String.t(),
          notify_url: String.t() | nil,
          amount: amount(),
          scene_info: scene_info(),
          goods_tag: goods_tag() | nil,
          settle_info: settle_info() | nil
        }

  #
  # 交易响应类型
  #

  @typedoc """
  JSAPI 支付响应参数

  返回包含预支付交易会话标识的 map，键为字符串类型：
  * "prepay_id" - 预支付交易会话标识
  """
  @type jsapi_transaction_resp :: %{
          String.t() => any()
        }

  @typedoc """
  Native 支付响应参数

  返回包含二维码链接的 map，键为字符串类型：
  * "code_url" - 二维码链接
  """
  @type native_transaction_resp :: %{
          String.t() => any()
        }

  @typedoc """
  H5 支付响应参数

  返回包含 H5 支付跳转链接的 map，键为字符串类型：
  * "h5_url" - H5 支付跳转链接
  """
  @type h5_transaction_resp :: %{
          String.t() => any()
        }

  @typedoc """
  交易查询响应参数

  返回包含完整交易详情的 map，键为字符串类型，包含以下字段：
  * "appid" - 应用 ID
  * "mchid" - 商户号
  * "out_trade_no" - 商户订单号
  * "transaction_id" - 微信支付订单号
  * "trade_type" - 交易类型
  * "trade_state" - 交易状态
  * "trade_state_desc" - 交易状态描述
  * "bank_type" - 付款银行
  * "success_time" - 支付完成时间
  * "payer" - 支付者信息
  * "amount" - 订单金额信息
  * "scene_info" - 支付场景描述
  * "promotion_detail" - 优惠信息
  """
  @type transaction_query_resp :: %{
          String.t() => any()
        }

  #
  # 退款相关类型
  #

  @typedoc """
  退款金额信息

  * `refund` - 退款金额（单位：分）
  * `total` - 原订单金额（单位：分）
  * `currency` - 货币类型，默认为 CNY（人民币）
  """
  @type refund_amount :: %{
          refund: non_neg_integer(),
          total: non_neg_integer(),
          currency: String.t()
        }

  @typedoc """
  退款请求参数

  * `out_refund_no` - 商户退款单号
  * `out_trade_no` - 商户订单号（与 transaction_id 二选一）
  * `transaction_id` - 微信支付订单号（与 out_trade_no 二选一）
  * `amount` - 退款金额信息
  * `reason` - 退款原因（可选）
  * `notify_url` - 退款结果通知地址（可选）
  * `funds_account` - 退款资金来源（可选）
  """
  @type refund_req :: %{
          out_refund_no: String.t(),
          out_trade_no: String.t() | nil,
          transaction_id: String.t() | nil,
          amount: refund_amount(),
          reason: String.t() | nil,
          notify_url: String.t() | nil,
          funds_account: String.t() | nil
        }

  @typedoc """
  退款响应参数

  返回包含退款详情的 map，键为字符串类型，包含以下字段：
  * "refund_id" - 微信支付退款号
  * "out_refund_no" - 商户退款单号
  * "transaction_id" - 微信支付订单号
  * "out_trade_no" - 商户订单号
  * "channel" - 退款渠道
  * "user_received_account" - 退款入账账户
  * "success_time" - 退款成功时间
  * "create_time" - 退款创建时间
  * "status" - 退款状态
  * "amount" - 金额信息
  """
  @type refund_resp :: %{
          String.t() => any()
        }

  @typedoc """
  退款查询响应参数

  返回包含退款查询详情的 map，键为字符串类型，包含以下字段：
  * "refund_id" - 微信支付退款号
  * "out_refund_no" - 商户退款单号
  * "transaction_id" - 微信支付订单号
  * "out_trade_no" - 商户订单号
  * "channel" - 退款渠道
  * "user_received_account" - 退款入账账户
  * "success_time" - 退款成功时间
  * "create_time" - 退款创建时间
  * "status" - 退款状态
  * "amount" - 金额信息
  * "promotion_detail" - 优惠退款信息
  """
  @type refund_query_resp :: %{
          String.t() => any()
        }

  #
  # HTTP 相关类型
  #

  @typedoc """
  HTTP 请求结构

  * `method` - HTTP 方法
  * `url` - 请求 URL
  * `headers` - 请求头
  * `body` - 请求体
  """
  @type http_request :: %{
          method: method(),
          url: String.t(),
          headers: headers(),
          body: body()
        }

  @typedoc """
  HTTP 响应结构

  * `status` - HTTP 状态码
  * `headers` - 响应头
  * `body` - 响应体
  """
  @type http_response :: %{
          status: http_status(),
          headers: headers(),
          body: body()
        }

  #
  # 通知相关类型
  #

  @typedoc """
  微信支付通知加密资源

  * `algorithm` - 加密算法
  * `ciphertext` - 密文
  * `associated_data` - 附加数据
  * `original_type` - 原始类型
  * `nonce` - 随机串
  """
  @type encrypted_resource :: %{
          algorithm: String.t(),
          ciphertext: String.t(),
          associated_data: String.t(),
          original_type: String.t(),
          nonce: String.t()
        }

  @typedoc """
  支付通知数据

  * `id` - 通知 ID
  * `create_time` - 通知创建时间
  * `event_type` - 通知类型
  * `resource_type` - 资源类型
  * `resource` - 通知资源数据
  * `summary` - 通知简要说明
  """
  @type payment_notification :: %{
          id: String.t(),
          create_time: String.t(),
          event_type: String.t(),
          resource_type: String.t(),
          resource: transaction_query_resp() | refund_query_resp(),
          summary: String.t()
        }
end
