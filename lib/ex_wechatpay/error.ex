defmodule ExWechatpay.Error do
  @moduledoc """
  Wechat Error
  """
  defexception [:message]

  @type t :: %__MODULE__{message: String.t()}

  def new(msg \\ "internal error"), do: %__MODULE__{message: msg}
end
