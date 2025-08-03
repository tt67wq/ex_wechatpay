defmodule ExWechatpay.Model.ConfigOption do
  @moduledoc """
  配置选项模块

  该模块定义了 ExWechatpay 的配置选项，并提供了配置验证功能。
  为了保持向后兼容性，该模块仍然保留，但内部使用了新的 ExWechatpay.Config.Schema 模块。
  """

  alias ExWechatpay.Config.Schema

  @type t :: Schema.t()

  @spec validate(keyword()) :: {:ok, keyword()} | {:error, term()}
  defdelegate validate(opts), to: Schema

  @spec validate!(keyword()) :: keyword()
  defdelegate validate!(opts), to: Schema
end
