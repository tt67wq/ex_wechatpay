defmodule ExWechatpay.Config.Helper do
  @moduledoc """
  配置助手模块

  该模块提供了一些便捷的配置管理函数，包括配置热更新、证书管理等。
  """

  alias ExWechatpay.Config.Manager
  alias ExWechatpay.Config.Schema

  @doc """
  获取当前配置

  ## 参数
    * `name` - 客户端名称

  ## 返回值
    * `config` - 当前配置
  """
  @spec get_config(atom()) :: keyword()
  def get_config(name) do
    Manager.get_config(name)
  end

  @doc """
  更新配置

  ## 参数
    * `name` - 客户端名称
    * `updates` - 要更新的配置

  ## 返回值
    * `{:ok, new_config}` - 更新后的配置
    * `{:error, error}` - 更新失败的错误信息
  """
  @spec update_config(atom(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def update_config(name, updates) do
    Manager.update_config(name, updates)
  end

  @doc """
  更新证书

  ## 参数
    * `name` - 客户端名称

  ## 返回值
    * `{:ok, new_config}` - 更新后的配置
    * `{:error, error}` - 更新失败的错误信息
  """
  @spec update_certificates(atom()) :: {:ok, keyword()} | {:error, term()}
  def update_certificates(name) do
    Manager.update_certificates(name, name)
  end

  @doc """
  启用自动更新证书

  ## 参数
    * `name` - 客户端名称
    * `interval` - 更新间隔（毫秒，默认：1天）

  ## 返回值
    * `:ok` - 成功启用
  """
  @spec enable_auto_update_certificates(atom(), non_neg_integer()) :: :ok
  def enable_auto_update_certificates(name, interval \\ 60_000 * 60 * 24) do
    Manager.enable_auto_update(name, name, interval)
  end

  @doc """
  禁用自动更新证书

  ## 参数
    * `name` - 客户端名称

  ## 返回值
    * `:ok` - 成功禁用
  """
  @spec disable_auto_update_certificates(atom()) :: :ok
  def disable_auto_update_certificates(name) do
    Manager.disable_auto_update(name)
  end

  @doc """
  获取配置模式文档

  该函数返回配置模式的详细文档，包括每个配置项的类型、默认值、说明等。

  ## 返回值
    * `docs` - 配置文档（Markdown 格式）
  """
  @spec config_docs() :: binary()
  def config_docs do
    Schema.docs()
  end

  @doc """
  检查配置是否有效

  ## 参数
    * `config` - 要检查的配置

  ## 返回值
    * `{:ok, validated_config}` - 配置有效
    * `{:error, error}` - 配置无效，包含错误信息
  """
  @spec validate_config(keyword()) :: {:ok, keyword()} | {:error, term()}
  def validate_config(config) do
    Schema.validate(config)
  end

  @doc """
  从环境变量加载配置

  ## 返回值
    * `config` - 从环境变量加载的配置
  """
  @spec load_from_env() :: keyword()
  def load_from_env do
    ExWechatpay.Config.Provider.load_env_config()
  end
end
