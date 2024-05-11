defmodule ExWechatpay.Model.Http do
  @moduledoc false
  defmodule Request do
    @moduledoc """
    http request
    """
    alias ExWechatpay.Typespecs

    require Logger

    @type t :: %__MODULE__{
            scheme: String.t(),
            host: String.t(),
            port: non_neg_integer(),
            method: Typespecs.method(),
            path: binary(),
            headers: Typespecs.headers(),
            body: Typespecs.body(),
            params: Typespecs.params(),
            opts: Typespecs.opts()
          }

    defstruct scheme: "https", host: "", port: 443, method: :get, path: "", headers: [], body: nil, params: %{}, opts: []

    @spec url(t()) :: URI.t()
    def url(%__MODULE__{scheme: scheme, host: host, port: port, path: path, params: params}) do
      query =
        if params in [nil, %{}] do
          nil
        else
          URI.encode_query(params)
        end

      %URI{
        scheme: scheme,
        host: host,
        path: path,
        query: query,
        port: port
      }
    end
  end

  defmodule Response do
    @moduledoc """
    http response
    """

    alias ExWechatpay.Typespecs

    @type t :: %__MODULE__{
            status_code: non_neg_integer(),
            headers: Typespecs.headers(),
            body: Typespecs.body()
          }

    defstruct status_code: 200, headers: [], body: nil
  end
end
