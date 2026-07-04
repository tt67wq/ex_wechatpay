defmodule ExWechatpay.VirtualPay.Client do
  @moduledoc """
  虚拟支付 xpay API 客户端

  封装微信虚拟支付的服务端接口调用：
  - query_balance: 查询代币余额
  - query_order: 查询订单状态
  - refund: 发起退款
  - notify_deliver: 通知发货
  - code2session: 用 code 换 session_key + openid

  所有 xpay 接口自动附加 access_token 和 pay_sig。
  """

  alias ExWechatpay.Exception
  alias ExWechatpay.VirtualPay.Signature
  alias ExWechatpay.VirtualPay.TokenAgent

  @base_url "https://api.weixin.qq.com"

  @doc """
  查询用户代币余额
  """
  @spec query_balance(atom(), String.t(), String.t(), String.t(), String.t(), String.t(), integer()) ::
          {:ok, map()} | {:error, Exception.t()}
  def query_balance(token_agent, appid, secret, app_key, openid, user_ip, env) do
    body = %{openid: openid, user_ip: user_ip, env: env}
    do_xpay_request(token_agent, appid, secret, app_key, "query_user_balance", body)
  end

  @doc """
  查询订单状态
  """
  @spec query_order(atom(), String.t(), String.t(), String.t(), String.t(), String.t(), integer()) ::
          {:ok, map()} | {:error, Exception.t()}
  def query_order(token_agent, appid, secret, app_key, openid, out_trade_no, env) do
    body = %{openid: openid, out_trade_no: out_trade_no, env: env}
    do_xpay_request(token_agent, appid, secret, app_key, "query_order", body)
  end

  @doc """
  发起退款
  """
  @spec refund(atom(), String.t(), String.t(), String.t(), String.t(), String.t(), integer(), integer()) ::
          {:ok, map()} | {:error, Exception.t()}
  def refund(token_agent, appid, secret, app_key, openid, out_trade_no, refund_fee, env) do
    body = %{openid: openid, out_trade_no: out_trade_no, refund_fee: refund_fee, env: env}
    do_xpay_request(token_agent, appid, secret, app_key, "refund_order", body)
  end

  @doc """
  通知微信已发货
  """
  @spec notify_deliver(atom(), String.t(), String.t(), String.t(), String.t(), String.t(), integer()) ::
          {:ok, map()} | {:error, Exception.t()}
  def notify_deliver(token_agent, appid, secret, app_key, openid, out_trade_no, env) do
    body = %{openid: openid, out_trade_no: out_trade_no, env: env}
    do_xpay_request(token_agent, appid, secret, app_key, "notify_provide_goods", body)
  end

  @doc """
  用 code 换 session_key + openid
  """
  @spec code2session(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, Exception.t()}
  def code2session(appid, secret, code) do
    url =
      "#{@base_url}/sns/jscode2session?appid=#{appid}&secret=#{secret}&js_code=#{code}&grant_type=authorization_code"

    case http_get(url) do
      {:ok, %{"session_key" => sk, "openid" => od}} ->
        {:ok, %{session_key: sk, openid: od}}

      {:ok, %{"errcode" => errcode, "errmsg" => errmsg}} ->
        {:error, Exception.new("code2session failed", %{code: errcode, message: errmsg})}

      {:ok, other} ->
        {:error, Exception.new("code2session unexpected response", other)}

      {:error, _} = err ->
        err
    end
  end

  # 统一 xpay 请求
  defp do_xpay_request(token_agent, appid, secret, app_key, path, body) do
    with {:ok, token} <- TokenAgent.get_token(token_agent, appid, secret) do
      body_json = Jason.encode!(body)
      full_path = "/xpay/#{path}"
      pay_sig = Signature.pay_sig(app_key, full_path, body_json)

      url = "#{@base_url}#{full_path}?access_token=#{token}&pay_sig=#{pay_sig}"

      case http_post(url, body_json) do
        {:ok, %{"errcode" => 0} = resp} ->
          {:ok, resp}

        {:ok, %{"errcode" => errcode, "errmsg" => errmsg}} ->
          {:error, Exception.new("xpay #{path} failed", %{code: errcode, message: errmsg})}

        {:ok, other} ->
          {:error, Exception.new("xpay #{path} unexpected response", other)}

        {:error, _} = err ->
          err
      end
    end
  end

  defp http_get(url) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body |> IO.iodata_to_binary() |> Jason.decode()

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, Exception.new("HTTP error", %{status: status, body: body})}

      {:error, reason} ->
        {:error, Exception.new("HTTP request failed", reason)}
    end
  end

  defp http_post(url, body) do
    content_type = ~c"application/json"

    case :httpc.request(:post, {String.to_charlist(url), [], content_type, body}, [], []) do
      {:ok, {{_, 200, _}, _headers, resp_body}} ->
        resp_body |> IO.iodata_to_binary() |> Jason.decode()

      {:ok, {{_, status, _}, _headers, resp_body}} ->
        {:error, Exception.new("HTTP error", %{status: status, body: resp_body})}

      {:error, reason} ->
        {:error, Exception.new("HTTP request failed", reason)}
    end
  end
end
