defmodule ExWechatpay.Core do
  @moduledoc """
  微信支付核心模块

  该模块是 ExWechatpay 的核心组件，负责初始化配置和委托各种功能到专门的模块。
  通过模块职责分离，提高了代码的可维护性和可扩展性。
  """

  use Agent

  alias ExWechatpay.Config.Provider
  alias ExWechatpay.Core.CertificateManager
  alias ExWechatpay.Core.RequestBuilder
  alias ExWechatpay.Core.ResponseHandler
  alias ExWechatpay.Core.SignatureManager
  alias ExWechatpay.Exception
  alias ExWechatpay.Service.Refund
  alias ExWechatpay.Service.Transaction
  alias ExWechatpay.Typespecs

  @type ok_t(ret) :: {:ok, ret}
  @type err_t() :: {:error, Exception.t()}

  @doc """
  启动核心模块并初始化配置

  ## 参数
    * `{name, finch, config}` - 包含名称、Finch 实例和配置的元组

  ## 返回值
    * `{:ok, pid}` - 成功启动的 Agent 进程 ID
    * `{:error, reason}` - 启动失败的原因
  """
  def start_link({name, finch, config}) do
    # 使用 Provider 加载配置
    {:ok, processed_config} =
      config
      |> Provider.load()
      |> case do
        {:ok, cfg} -> {:ok, Keyword.put(cfg, :finch, finch)}
        error -> error
      end

    Agent.start_link(fn -> processed_config end, name: name)
  end

  @doc """
  获取当前配置

  ## 参数
    * `name` - Agent 名称

  ## 返回值
    * `ConfigOption.t()` - 当前配置
  """
  def get(name) do
    Agent.get(name, & &1)
  end

  @doc """
  更新配置

  ## 参数
    * `name` - Agent 名称
    * `updates` - 配置更新

  ## 返回值
    * `{:ok, ConfigOption.t()}` - 更新后的配置
    * `{:error, reason}` - 更新失败的原因
  """
  def update_config(name, updates) do
    Provider.update_config(name, updates)
  end

  @doc """
  生成小程序支付表单

  ## 参数
    * `name` - Agent 名称
    * `prepay_id` - 预支付 ID

  ## 返回值
    * `Typespecs.dict()` - 小程序支付表单
  """
  @spec miniapp_payform(module(), String.t()) :: Typespecs.dict()
  def miniapp_payform(name, prepay_id) do
    config = get(name)
    RequestBuilder.build_miniapp_payform(config, prepay_id)
  end

  @doc """
  获取微信支付平台证书

  ## 参数
    * `name` - Agent 名称
    * `verify` - 是否验证证书，默认为 true

  ## 返回值
    * `{:ok, map()}` - 成功获取的证书信息
    * `{:error, Exception.t()}` - 获取证书失败的错误信息
  """
  @spec get_certificates(module(), boolean()) :: {:ok, Typespecs.dict()} | err_t()
  def get_certificates(name, verify \\ true) do
    config = get(name)
    CertificateManager.get_certificates(config, config[:finch], verify)
  end

  @doc """
  验证微信支付回调或响应签名

  ## 参数
    * `name` - Agent 名称
    * `headers` - HTTP 响应头
    * `body` - HTTP 响应体

  ## 返回值
    * `boolean()` - 验证结果，`true` 表示验证通过
  """
  @spec verify(module(), Typespecs.headers(), Typespecs.body()) :: boolean()
  def verify(name, headers, body) do
    name
    |> get()
    |> SignatureManager.verify_signature(headers, body)
  end

  @doc """
  解密微信支付加密数据

  ## 参数
    * `name` - Agent 名称
    * `encrypted_form` - 加密数据

  ## 返回值
    * `{:ok, binary()}` - 解密后的数据
    * `{:error, Exception.t()}` - 解密失败的错误信息
  """
  @spec decrypt(module(), Typespecs.dict()) :: {:ok, binary()} | err_t()
  def decrypt(name, encrypted_form) do
    name
    |> get()
    |> ResponseHandler.decrypt(encrypted_form)
    |> case do
      :error -> {:error, Exception.new("decrypt_failed", %{"encrypted_form" => encrypted_form})}
      ret -> {:ok, ret}
    end
  end

  @doc """
  创建 Native 支付交易

  ## 参数
    * `name` - Agent 名称
    * `args` - 交易参数

  ## 返回值
    * `{:ok, map()}` - 成功创建的交易信息
    * `{:error, Exception.t()}` - 创建交易失败的错误信息
  """
  @spec create_native_transaction(module(), Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
  def create_native_transaction(name, args) do
    config = get(name)
    Transaction.create_native_transaction(config, config[:finch], args)
  end

  @doc """
  创建 JSAPI 支付交易

  ## 参数
    * `name` - Agent 名称
    * `args` - 交易参数

  ## 返回值
    * `{:ok, map()}` - 成功创建的交易信息
    * `{:error, Exception.t()}` - 创建交易失败的错误信息
  """
  @spec create_jsapi_transaction(module(), Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
  def create_jsapi_transaction(name, args) do
    config = get(name)
    Transaction.create_jsapi_transaction(config, config[:finch], args)
  end

  @doc """
  创建 H5 支付交易

  ## 参数
    * `name` - Agent 名称
    * `args` - 交易参数

  ## 返回值
    * `{:ok, map()}` - 成功创建的交易信息
    * `{:error, Exception.t()}` - 创建交易失败的错误信息
  """
  @spec create_h5_transaction(module(), Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
  def create_h5_transaction(name, args) do
    config = get(name)
    Transaction.create_h5_transaction(config, config[:finch], args)
  end

  @doc """
  通过商户订单号查询交易

  ## 参数
    * `name` - Agent 名称
    * `out_trade_no` - 商户订单号

  ## 返回值
    * `{:ok, map()}` - 交易信息
    * `{:error, Exception.t()}` - 查询失败的错误信息
  """
  @spec query_transaction_by_out_trade_no(module(), binary()) :: ok_t(Typespecs.dict()) | err_t()
  def query_transaction_by_out_trade_no(name, out_trade_no) do
    config = get(name)
    Transaction.query_transaction_by_out_trade_no(config, config[:finch], out_trade_no)
  end

  @doc """
  通过微信支付订单号查询交易

  ## 参数
    * `name` - Agent 名称
    * `transaction_id` - 微信支付订单号

  ## 返回值
    * `{:ok, map()}` - 交易信息
    * `{:error, Exception.t()}` - 查询失败的错误信息
  """
  @spec query_transaction_by_transaction_id(module(), binary()) :: ok_t(Typespecs.dict()) | err_t()
  def query_transaction_by_transaction_id(name, transaction_id) do
    config = get(name)
    Transaction.query_transaction_by_transaction_id(config, config[:finch], transaction_id)
  end

  @doc """
  关闭交易

  ## 参数
    * `name` - Agent 名称
    * `out_trade_no` - 商户订单号

  ## 返回值
    * `:ok` - 关闭成功
    * `{:error, Exception.t()}` - 关闭失败的错误信息
  """
  @spec close_transaction(module(), binary()) :: :ok | err_t()
  def close_transaction(name, out_trade_no) do
    config = get(name)
    Transaction.close_transaction(config, config[:finch], out_trade_no)
  end

  @doc """
  创建退款

  ## 参数
    * `name` - Agent 名称
    * `args` - 退款参数

  ## 返回值
    * `{:ok, map()}` - 成功创建的退款信息
    * `{:error, Exception.t()}` - 创建退款失败的错误信息
  """
  @spec create_refund(module(), Typespecs.dict()) :: ok_t(Typespecs.dict()) | err_t()
  def create_refund(name, args) do
    config = get(name)
    Refund.create_refund(config, config[:finch], args)
  end
end
