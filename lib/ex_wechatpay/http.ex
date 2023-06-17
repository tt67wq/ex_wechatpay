defmodule ExWechatpay.Http do
  @moduledoc """
  微信支付 HTTP 请求 behavior, default http client is Finch
  you can implement your own http client via this behavior
  """

  @type t :: struct()

  @type opts :: keyword()
  @type method :: Finch.Request.method()
  @type body :: iodata() | nil
  @type params :: %{String.t() => any()} | nil
  @type headers :: [{String.t(), String.t()}]
  @type http_status :: non_neg_integer()

  @callback new(opts()) :: t()
  @callback start_link(http: t()) :: GenServer.on_start()
  @callback do_request(
              http :: t(),
              method :: method(),
              path :: bitstring(),
              headers :: headers(),
              body :: body(),
              params :: params(),
              opts :: opts()
            ) :: {http_status(), headers(), iodata()}

  @spec do_request(
          t(),
          method(),
          bitstring(),
          headers(),
          body(),
          params(),
          opts()
        ) :: {http_status(), headers(), iodata()}
  def do_request(http, method, path, headers, body, params, opts) do
    delegate(http, :do_request, [method, path, headers, body, params, opts])
  end

  defp delegate(%module{} = client, func, args),
    do: apply(module, func, [client | args])
end

defmodule ExWechatpay.Http.Finch do
  @moduledoc """
  微信支付 HTTP 请求实现 via Finch
  """
  alias ExWechatpay.{Http, Error}

  @behaviour Http

  require Logger

  defstruct [:name]

  @impl Http
  def new(opts \\ []) do
    opts = opts |> Keyword.put_new(:name, __MODULE__)
    struct(__MODULE__, opts)
  end

  @impl Http
  def do_request(client, method, path, headers, body, params, opts) do
    Logger.debug(%{
      "method" => method,
      "path" => path,
      "headers" => headers,
      "body" => body,
      "params" => params,
      "opts" => opts
    })

    with opts <- Keyword.put_new(opts, :receive_timeout, 2000),
         req <-
           Finch.build(
             method,
             url(path, params),
             headers,
             body,
             opts
           ) do
      Finch.request(req, client.name)
      |> case do
        {:ok, %Finch.Response{status: 204}} ->
          {204, [], nil}

        {:ok, %Finch.Response{status: status, body: body, headers: resp_headers}} ->
          {status, resp_headers, body}

        {:error, exception} ->
          Logger.error(%{"path" => path, "error" => exception})
          raise Error.new(inspect(exception))
      end
    end
  end

  defp url(path, nil), do: path
  defp url(path, params) when params == %{}, do: path
  defp url(path, params), do: path <> "?" <> URI.encode_query(params)

  def child_spec(opts) do
    http = Keyword.fetch!(opts, :http)
    %{id: {__MODULE__, http.name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl Http
  def start_link(opts) do
    {http, opts} = Keyword.pop!(opts, :http)

    opts
    |> Keyword.put(:name, http.name)
    |> Finch.start_link()
  end
end
