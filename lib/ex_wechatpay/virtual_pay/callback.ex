defmodule ExWechatpay.VirtualPay.Callback do
  @moduledoc """
  虚拟支付回调解析工具

  提供微信虚拟支付的回调通知解析函数：
  - parse_deliver: 解析发货通知
  - parse_refund: 解析退款通知
  - success_response: 返回成功响应 JSON

  回调无签名验证，仅做 JSON 解析 + 字段名容错（大小写）。
  """

  alias ExWechatpay.Exception

  @doc """
  解析发货回调通知

  微信发货通知字段名大小写可能不一致，此函数做容错处理。

  ## 参数
    * `body_or_params` - 请求体字符串或已解析的 map

  ## 返回值
    * `{:ok, map()}` - 解析成功，包含 openid, out_trade_no, product_id
    * `{:error, Exception.t()}` - 解析失败

  ## 示例
      iex> parse_deliver(~s({"OpenId":"xxx","OutTradeNo":"VP123","GoodsInfo":{"ProductId":"vip_six_week"}}))
      {:ok, %{openid: "xxx", out_trade_no: "VP123", product_id: "vip_six_week"}}
  """
  @spec parse_deliver(String.t() | map()) :: {:ok, map()} | {:error, Exception.t()}
  def parse_deliver(body_or_params) do
    with {:ok, params} <- ensure_map(body_or_params) do
      openid = get_field(params, ["OpenId", "openid", "open_id"])
      out_trade_no = get_field(params, ["OutTradeNo", "out_trade_no"])
      product_id = extract_product_id(params)

      if openid && out_trade_no do
        {:ok, %{openid: openid, out_trade_no: out_trade_no, product_id: product_id}}
      else
        {:error, Exception.new("Missing required fields in deliver callback", params)}
      end
    end
  end

  @doc """
  解析退款回调通知

  ## 参数
    * `body_or_params` - 请求体字符串或已解析的 map

  ## 返回值
    * `{:ok, map()}` - 解析成功，包含 openid, wx_refund_id, refund_fee, ret_code
    * `{:error, Exception.t()}` - 解析失败
  """
  @spec parse_refund(String.t() | map()) :: {:ok, map()} | {:error, Exception.t()}
  def parse_refund(body_or_params) do
    with {:ok, params} <- ensure_map(body_or_params) do
      openid = get_field(params, ["OpenId", "openid"])
      wx_refund_id = get_field(params, ["WxRefundId", "wx_refund_id"])
      refund_fee = get_field(params, ["RefundFee", "refund_fee"])
      ret_code = get_field(params, ["RetCode", "ret_code"])

      if openid && wx_refund_id do
        {:ok,
         %{
           openid: openid,
           wx_refund_id: wx_refund_id,
           refund_fee: refund_fee,
           ret_code: ret_code
         }}
      else
        {:error, Exception.new("Missing required fields in refund callback", params)}
      end
    end
  end

  @doc """
  返回成功响应 JSON

  微信回调要求返回固定格式的成功响应。

  ## 返回值
    * `map()` - %{"ErrCode" => 0, "ErrMsg" => "success"}
  """
  @spec success_response() :: map()
  def success_response do
    %{"ErrCode" => 0, "ErrMsg" => "success"}
  end

  # 确保输入是 map
  defp ensure_map(params) when is_map(params), do: {:ok, params}

  defp ensure_map(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, params} -> {:ok, params}
      {:error, reason} -> {:error, Exception.new("Failed to parse callback JSON", reason)}
    end
  end

  defp ensure_map(_), do: {:error, Exception.new("Invalid callback input", nil)}

  # 容错取字段（大小写）
  defp get_field(params, keys) do
    Enum.find_value(keys, fn key ->
      Map.get(params, key)
    end)
  end

  # 从 GoodsInfo 提取 ProductId
  defp extract_product_id(params) do
    goods_info =
      get_field(params, ["GoodsInfo", "goods_info"]) || %{}

    if is_map(goods_info) do
      get_field(goods_info, ["ProductId", "product_id"])
    end
  end
end
