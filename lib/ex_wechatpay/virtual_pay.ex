defmodule ExWechatpay.VirtualPay do
  @moduledoc """
  虚拟支付主入口模块

  提供微信虚拟支付的完整 API：
  - sign: 生成支付签名（组装 signData + 计算所有签名）
  - query_balance: 查询代币余额
  - query_order: 查询订单状态
  - refund: 发起退款
  - notify_deliver: 通知发货
  - code2session: 用 code 换 session_key + openid

  此模块是 VirtualPay 子系统的门面，内部委托给 Client/Signature/Callback 等子模块。
  """

  alias ExWechatpay.Exception
  alias ExWechatpay.VirtualPay.Client
  alias ExWechatpay.VirtualPay.Signature

  @doc """
  生成支付签名

  组装 signData 并计算所有签名，返回前端 wx.requestVirtualPayment 所需的全部数据。

  ## 参数
    * `config` - 配置（包含 appid, secret, virtual_pay 子键）
    * `args` - 参数
      * `:product_id` - 道具 ID，如 "vip_six_week"
      * `:out_trade_no` - 商户订单号
      * `:code` - wx.login() 获取的 code
      * `:goods_price` - 价格（分）
      * `:buy_quantity` - 购买数量（默认 1）
      * `:attach` - 自定义透传字段（默认 "ex_wechatpay"）

  ## 返回值
    * `{:ok, map()}` - 成功，包含 sign_data, sign_data_str, pay_sig, signature, session_key, openid
    * `{:error, Exception.t()}` - 失败

  ## 重要
    * `sign_data_str` 必须原样传给前端，前端不能再 JSON.stringify
    * `pay_sig` 已包含 "requestVirtualPayment&" 前缀
  """
  @spec sign(keyword(), keyword()) :: {:ok, map()} | {:error, Exception.t()}
  def sign(config, args) do
    vp_config = config[:virtual_pay]
    appid = config[:appid]
    secret = config[:secret]
    env = vp_config[:env]
    offer_id = vp_config[:offer_id]
    app_key = select_app_key(vp_config, env)

    product_id = Keyword.fetch!(args, :product_id)
    out_trade_no = Keyword.fetch!(args, :out_trade_no)
    code = Keyword.fetch!(args, :code)
    goods_price = Keyword.fetch!(args, :goods_price)
    buy_quantity = Keyword.get(args, :buy_quantity, 1)
    attach = Keyword.get(args, :attach, "ex_wechatpay")

    with {:ok, %{session_key: session_key, openid: _openid}} <- Client.code2session(appid, secret, code) do
      # 组装 signData
      sign_data = %{
        "offerId" => offer_id,
        "buyQuantity" => buy_quantity,
        "env" => env,
        "currencyType" => "CNY",
        "productId" => product_id,
        "goodsPrice" => goods_price,
        "outTradeNo" => out_trade_no,
        "attach" => attach,
        "mode" => "short_series_goods"
      }

      # 序列化为 JSON（字节级精确）
      sign_data_str = Jason.encode!(sign_data)

      # 计算签名
      pay_sig = Signature.client_pay_sig(app_key, sign_data_str)
      signature = Signature.user_signature(session_key, sign_data_str)

      {:ok,
       %{
         sign_data: sign_data,
         sign_data_str: sign_data_str,
         pay_sig: pay_sig,
         signature: signature,
         session_key: session_key
       }}
    end
  end

  @doc """
  查询代币余额
  """
  @spec query_balance(keyword(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Exception.t()}
  def query_balance(config, openid, user_ip) do
    {token_agent, appid, secret, app_key, env} = extract_config(config)
    Client.query_balance(token_agent, appid, secret, app_key, openid, user_ip, env)
  end

  @doc """
  查询订单状态
  """
  @spec query_order(keyword(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Exception.t()}
  def query_order(config, openid, out_trade_no) do
    {token_agent, appid, secret, app_key, env} = extract_config(config)
    Client.query_order(token_agent, appid, secret, app_key, openid, out_trade_no, env)
  end

  @doc """
  发起退款
  """
  @spec refund(keyword(), String.t(), String.t(), integer()) ::
          {:ok, map()} | {:error, Exception.t()}
  def refund(config, openid, out_trade_no, refund_fee) do
    {token_agent, appid, secret, app_key, env} = extract_config(config)
    Client.refund(token_agent, appid, secret, app_key, openid, out_trade_no, refund_fee, env)
  end

  @doc """
  通知发货
  """
  @spec notify_deliver(keyword(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Exception.t()}
  def notify_deliver(config, openid, out_trade_no) do
    {token_agent, appid, secret, app_key, env} = extract_config(config)
    Client.notify_deliver(token_agent, appid, secret, app_key, openid, out_trade_no, env)
  end

  @doc """
  用 code 换 session_key + openid
  """
  @spec code2session(keyword(), String.t()) ::
          {:ok, map()} | {:error, Exception.t()}
  def code2session(config, code) do
    appid = config[:appid]
    secret = config[:secret]
    Client.code2session(appid, secret, code)
  end

  # 根据 env 选择 app_key
  defp select_app_key(vp_config, env) do
    if env == 1 do
      vp_config[:app_key_sandbox] || vp_config[:app_key]
    else
      vp_config[:app_key]
    end
  end

  # 从 config 提取虚拟支付相关参数
  defp extract_config(config) do
    vp_config = config[:virtual_pay]
    appid = config[:appid]
    secret = config[:secret]
    env = vp_config[:env]
    app_key = select_app_key(vp_config, env)
    token_agent = config[:virtual_pay_token_agent]

    {token_agent, appid, secret, app_key, env}
  end
end
