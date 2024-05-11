defmodule ExWechatpay.Typespecs do
  @moduledoc """
  some typespecs
  """

  @type name :: atom() | {:global, term()} | {:via, module(), term()}
  @type opts :: keyword()
  @type method :: :get | :post | :head | :patch | :delete | :options | :put
  @type api :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type body :: binary() | nil
  @type params :: %{String.t() => binary()} | nil
  @type http_status :: non_neg_integer()
  @type on_start ::
          {:ok, pid()}
          | :ignore
          | {:error, {:already_started, pid()} | term()}

  @type dict :: %{String.t() => any()}
end
