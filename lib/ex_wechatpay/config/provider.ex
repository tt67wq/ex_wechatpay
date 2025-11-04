defmodule ExWechatpay.Config.Provider do
  @moduledoc """
  配置提供者模块

  该模块负责加载和管理 ExWechatpay 的配置，支持从多种来源获取配置：
  1. 直接传入的配置
  2. 应用程序配置
  3. 环境变量

  通过这种方式，可以灵活地管理配置，同时支持配置热更新。
  """

  alias ExWechatpay.Config.Schema
  alias ExWechatpay.Util

  # 环境变量前缀
  @env_prefix "EX_WECHATPAY_"

  @doc """
  加载配置

  ## 参数
    * `config` - 直接传入的配置

  ## 返回值
    * `{:ok, config}` - 成功加载的配置
    * `{:error, error}` - 加载失败的错误信息

  配置加载优先级：直接传入的配置 > 应用程序配置 > 环境变量 > 默认值
  """
  @spec load(keyword()) :: {:ok, keyword()} | {:error, term()}
  def load(config) do
    # 合并配置（直接传入的优先级最高）
    merged_config =
      []
      |> Keyword.merge(load_env_config())
      |> Keyword.merge(config)

    # 3. 验证配置
    case Schema.validate(merged_config) do
      {:ok, validated_config} ->
        {:ok, prepare_config(validated_config)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  从环境变量加载配置

  环境变量需要以 `EX_WECHATPAY_` 为前缀，例如：
  - `EX_WECHATPAY_APPID`
  - `EX_WECHATPAY_MCHID`
  - `EX_WECHATPAY_SERVICE_HOST`

  对于复杂结构，可以使用 JSON 格式的字符串，例如：
  - `EX_WECHATPAY_WX_PUBS='[{"wechatpay-serial": "pem-content"}]'`

  ## 返回值
    * `keyword()` - 从环境变量加载的配置
  """
  @spec load_env_config() :: keyword()
  def load_env_config do
    env_keys = [
      {"APPID", :appid},
      {"MCHID", :mchid},
      {"SERVICE_HOST", :service_host},
      {"NOTIFY_URL", :notify_url},
      {"APIV3_KEY", :apiv3_key},
      {"WX_PUBS", :wx_pubs},
      {"CLIENT_SERIAL_NO", :client_serial_no},
      {"CLIENT_KEY", :client_key},
      {"CLIENT_CERT", :client_cert}
    ]

    Enum.reduce(env_keys, [], fn {env_key, config_key}, acc ->
      case System.get_env(@env_prefix <> env_key) do
        nil ->
          acc

        value ->
          parsed_value = parse_env_value(config_key, value)
          Keyword.put(acc, config_key, parsed_value)
      end
    end)
  end

  @doc """
  准备配置，进行必要的转换

  ## 参数
    * `config` - 原始配置

  ## 返回值
    * `keyword()` - 处理后的配置
  """
  @spec prepare_config(keyword()) :: keyword()
  def prepare_config(config) do
    config
    |> Keyword.update(:client_key, nil, &load_pem_if_string/1)
    |> Keyword.update(:client_cert, nil, &load_pem_if_string/1)
    |> Keyword.update(:wx_pubs, [], &prepare_wx_pubs/1)
  end

  @doc """
  更新现有配置

  ## 参数
    * `agent` - 配置 Agent 名称
    * `updates` - 要更新的配置

  ## 返回值
    * `{:ok, new_config}` - 更新后的配置
    * `{:error, error}` - 更新失败的错误信息
  """
  @spec update_config(atom(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def update_config(agent, updates) do
    current_config = get_current_config(agent)

    # 合并更新
    updated_config = Keyword.merge(current_config, updates)

    # 验证更新后的配置
    case Schema.validate(updated_config) do
      {:ok, validated_config} ->
        prepared_config = prepare_config(validated_config)
        set_config(agent, prepared_config)
        {:ok, prepared_config}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  获取当前配置

  ## 参数
    * `agent` - 配置 Agent 名称

  ## 返回值
    * `keyword()` - 当前配置
  """
  @spec get_current_config(atom()) :: keyword()
  def get_current_config(agent) do
    Agent.get(agent, & &1)
  end

  @doc """
  设置配置

  ## 参数
    * `agent` - 配置 Agent 名称
    * `config` - 新配置

  ## 返回值
    * `:ok` - 设置成功
  """
  @spec set_config(atom(), keyword()) :: :ok
  def set_config(agent, config) do
    Agent.update(agent, fn _ -> config end)
  end

  # 私有辅助函数

  # 解析环境变量值
  defp parse_env_value(:wx_pubs, value) do
    Jason.decode!(value)
  rescue
    _ -> value
  end

  defp parse_env_value(_, value), do: value

  # 如果是字符串，则加载 PEM
  defp load_pem_if_string(value) when is_binary(value), do: Util.load_pem!(value)
  defp load_pem_if_string(value), do: value

  # 准备微信平台证书列表
  defp prepare_wx_pubs(wx_pubs) when is_list(wx_pubs) do
    Enum.map(wx_pubs, fn
      {k, v} when is_binary(v) -> {k, Util.load_pem!(v)}
      pair -> pair
    end)
  end

  defp prepare_wx_pubs(wx_pubs), do: wx_pubs
end
