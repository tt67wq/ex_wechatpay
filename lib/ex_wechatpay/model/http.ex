defmodule ExWechatpay.Model.Http do
  @moduledoc """
  HTTP 模型模块

  该模块定义了 HTTP 请求和响应的数据结构，用于规范化 HTTP 交互。
  通过明确的数据结构定义，提高了代码的可读性和类型安全性。
  """

  defmodule Request do
    @moduledoc """
    HTTP 请求结构

    定义了 HTTP 请求的各个组成部分，包括请求方法、URL、请求头和请求体等。
    """
    alias ExWechatpay.Typespecs

    require Logger

    @type t :: %__MODULE__{
            scheme: String.t(),
            host: String.t(),
            port: non_neg_integer(),
            method: Typespecs.method(),
            path: String.t(),
            headers: Typespecs.headers(),
            body: Typespecs.body(),
            params: Typespecs.params(),
            opts: Typespecs.opts()
          }

    defstruct scheme: "https", host: "", port: 443, method: :get, path: "", headers: [], body: nil, params: %{}, opts: []

    @doc """
    生成完整的请求 URL

    ## 参数
      * `request` - HTTP 请求结构

    ## 返回值
      * `URI.t()` - 完整的请求 URI
    """
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
    HTTP 响应结构

    定义了 HTTP 响应的各个组成部分，包括状态码、响应头和响应体等。
    """

    alias ExWechatpay.Typespecs

    @type t :: %__MODULE__{
            status_code: Typespecs.http_status(),
            headers: Typespecs.headers(),
            body: Typespecs.body()
          }

    defstruct status_code: 200, headers: [], body: nil
  end
end
