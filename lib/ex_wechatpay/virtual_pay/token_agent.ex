defmodule ExWechatpay.VirtualPay.TokenAgent do
  @moduledoc """
  虚拟支付 access_token 缓存代理

  管理微信 access_token 的缓存和自动刷新。
  access_token 有效期 7200 秒，过期前 300 秒自动刷新。

  每个商户配置对应一个独立的 TokenAgent 实例。
  """

  use Agent

  alias ExWechatpay.Exception

  @doc """
  启动 TokenAgent

  ## 参数
    * `opts` - 选项
      * `:name` - 进程名称（必需）

  ## 返回值
    * `{:ok, pid()}` - 启动成功
    * `{:error, reason}` - 启动失败
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Agent.start_link(fn -> %{token: nil, expires_at: 0} end, name: name)
  end

  @doc """
  获取 access_token

  如果 token 已过期或即将过期（300 秒内），自动刷新。

  ## 参数
    * `name` - TokenAgent 进程名称
    * `appid` - 小程序 AppID
    * `secret` - 小程序 secret

  ## 返回值
    * `{:ok, token}` - 获取成功
    * `{:error, exception}` - 获取失败
  """
  @spec get_token(atom(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def get_token(name, appid, secret) do
    Agent.get_and_update(name, fn state ->
      now = System.system_time(:second)

      if state.token != nil and state.expires_at - now > 300 do
        # Token 仍然有效
        {{:ok, state.token}, state}
      else
        # 需要刷新
        case refresh_token(appid, secret) do
          {:ok, token, expires_in} ->
            new_state = %{
              token: token,
              expires_at: now + expires_in
            }

            {{:ok, token}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
      end
    end)
  end

  @doc """
  强制刷新 access_token

  ## 参数
    * `name` - TokenAgent 进程名称
    * `appid` - 小程序 AppID
    * `secret` - 小程序 secret

  ## 返回值
    * `{:ok, token}` - 刷新成功
    * `{:error, exception}` - 刷新失败
  """
  @spec refresh(atom(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def refresh(name, appid, secret) do
    case refresh_token(appid, secret) do
      {:ok, token, expires_in} ->
        now = System.system_time(:second)

        Agent.update(name, fn _state ->
          %{token: token, expires_at: now + expires_in}
        end)

        {:ok, token}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # 调用微信接口获取 access_token
  @spec refresh_token(String.t(), String.t()) ::
          {:ok, String.t(), integer()} | {:error, Exception.t()}
  defp refresh_token(appid, secret) do
    url =
      "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{appid}&secret=#{secret}"

    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body_str = IO.iodata_to_binary(body)

        case Jason.decode(body_str) do
          {:ok, %{"access_token" => token, "expires_in" => expires_in}} ->
            {:ok, token, expires_in}

          {:ok, %{"errcode" => errcode, "errmsg" => errmsg}} ->
            {:error, Exception.new("Failed to get access_token", %{code: errcode, message: errmsg})}

          {:error, reason} ->
            {:error, Exception.new("Failed to parse access_token response", reason)}
        end

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, Exception.new("HTTP error getting access_token", %{status: status, body: body})}

      {:error, reason} ->
        {:error, Exception.new("HTTP request failed for access_token", reason)}
    end
  end
end
