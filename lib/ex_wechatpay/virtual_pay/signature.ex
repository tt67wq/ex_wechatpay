defmodule ExWechatpay.VirtualPay.Signature do
  @moduledoc """
  虚拟支付签名工具模块

  提供微信虚拟支付所需的三种 HMAC-SHA256 签名：
  - pay_sig: 服务端 API 签名（调用 xpay 接口用）
  - client_pay_sig: 客户端签名（返回给前端 wx.requestVirtualPayment）
  - user_signature: 用户态签名（用 session_key 计算）

  所有签名输出均为 hex 小写字符串。
  """

  @doc """
  服务端 API 签名（pay_sig）

  用于调用 xpay 服务端接口（query_user_balance, query_order 等）。

  ## 参数
    * `app_key` - 应用密钥（根据 env 选择现网或沙箱）
    * `path` - API 路径，如 "/xpay/query_user_balance"
    * `body` - 请求体 JSON 字符串

  ## 返回值
    * `String.t()` - hex 小写签名字符串

  ## 示例
      iex> pay_sig("app_key_123", "/xpay/query_user_balance", ~s({"openid":"xxx"}))
      "a1b2c3d4..."
  """
  @spec pay_sig(String.t(), String.t(), String.t()) :: String.t()
  def pay_sig(app_key, path, body) do
    message = path <> "&" <> body
    hmac_sha256(app_key, message)
  end

  @doc """
  客户端签名（client_pay_sig）

  返回给前端，用于 wx.requestVirtualPayment 的 paySig 参数。

  ## 参数
    * `app_key` - 应用密钥
    * `sign_data_str` - signData 的 JSON 字符串（必须与前端传给微信的字节一致）

  ## 返回值
    * `String.t()` - hex 小写签名字符串

  ## 注意
    签名消息自动包含 "requestVirtualPayment&" 前缀，不可省略。

  ## 示例
      iex> client_pay_sig("app_key_123", ~s({"offerId":"123",...}))
      "d4e5f6..."
  """
  @spec client_pay_sig(String.t(), String.t()) :: String.t()
  def client_pay_sig(app_key, sign_data_str) do
    message = "requestVirtualPayment&" <> sign_data_str
    hmac_sha256(app_key, message)
  end

  @doc """
  用户态签名（user_signature）

  用 session_key 计算，返回给前端用于 wx.requestVirtualPayment 的 signature 参数。

  ## 参数
    * `session_key` - 用户 session_key（通过 code2session 获取）
    * `sign_data_str` - signData 的 JSON 字符串

  ## 返回值
    * `String.t()` - hex 小写签名字符串

  ## 示例
      iex> user_signature("session_key_xxx", ~s({"offerId":"123",...}))
      "g7h8i9..."
  """
  @spec user_signature(String.t(), String.t()) :: String.t()
  def user_signature(session_key, sign_data_str) do
    hmac_sha256(session_key, sign_data_str)
  end

  # 内部 HMAC-SHA256 计算，输出 hex 小写
  @spec hmac_sha256(String.t(), String.t()) :: String.t()
  defp hmac_sha256(key, message) do
    :hmac
    |> :crypto.mac(:sha256, key, message)
    |> Base.encode16(case: :lower)
  end
end
