defmodule ExWechatpay.Http do
  @moduledoc """
  behavior os http transport
  """
  alias ExWechatpay.{Error, Typespecs}

  @type t :: struct()

  @callback new(Typespecs.opts()) :: t()
  @callback start_link(http: t()) :: Typespecs.on_start()
  @callback do_request(
              http :: t(),
              req :: ExWechatpay.Http.Request.t()
            ) ::
              {:ok, ExWechatpay.Http.Response.t()} | {:error, Error.t()}

  defp delegate(%module{} = http, func, args),
    do: apply(module, func, [http | args])

  @spec do_request(t(), ExWechatpay.Http.Request.t()) ::
          {:ok, ExWechatpay.Http.Response.t()}
          | {:error, Error.t()}
  def do_request(http, req), do: delegate(http, :do_request, [req])

  def start_link(%module{} = http) do
    apply(module, :start_link, [[http: http]])
  end
end

defmodule ExWechatpay.Http.Request do
  @moduledoc """
  http request
  """
  require Logger

  alias ExWechatpay.{Typespecs}

  @http_request_schema [
    scheme: [
      type: :string,
      doc: "http scheme",
      default: "https"
    ],
    host: [
      type: :string,
      doc: "http host",
      required: true
    ],
    port: [
      type: :integer,
      doc: "http port",
      default: 443
    ],
    method: [
      type: :any,
      doc: "http method",
      default: :get
    ],
    path: [
      type: :string,
      doc: "http path",
      default: "/"
    ],
    headers: [
      type: {:list, :any},
      doc: "http headers",
      default: []
    ],
    body: [
      type: :any,
      doc: "http body",
      default: nil
    ],
    params: [
      type: {:map, :string, :string},
      doc: "http query params",
      default: %{}
    ],
    opts: [
      type: :keyword_list,
      doc: "http opts",
      default: []
    ]
  ]

  @type http_request_schema_t :: [unquote(NimbleOptions.option_typespec(@http_request_schema))]

  @type t :: %__MODULE__{
          scheme: String.t(),
          host: String.t(),
          port: non_neg_integer(),
          method: Typespecs.method(),
          path: bitstring(),
          headers: Typespecs.headers(),
          body: Typespecs.body(),
          params: Typespecs.params(),
          opts: Typespecs.opts()
        }

  defstruct [
    :scheme,
    :host,
    :port,
    :method,
    :path,
    :headers,
    :body,
    :params,
    :opts
  ]

  @doc """
  create new http request instance

  ## Params
  #{NimbleOptions.docs(@http_request_schema)}
  """
  @spec new(http_request_schema_t()) :: t()
  def new(opts) do
    opts = opts |> NimbleOptions.validate!(@http_request_schema)
    struct(__MODULE__, opts)
  end

  @spec url(t()) :: URI.t()
  def url(req) do
    query =
      if req.params in [nil, %{}] do
        nil
      else
        req.params |> URI.encode_query()
      end

    %URI{
      scheme: req.scheme,
      host: req.host,
      path: req.path,
      query: query,
      port: req.port
    }
  end
end

defmodule ExWechatpay.Http.Response do
  @moduledoc """
  http response
  """

  alias ExWechatpay.{Typespecs}

  @http_response_schema [
    status_code: [
      type: :integer,
      doc: "http status code",
      default: 200
    ],
    headers: [
      type: {:list, :any},
      doc: "http headers",
      default: []
    ],
    body: [
      type: :string,
      doc: "http body",
      default: ""
    ]
  ]

  @type t :: %__MODULE__{
          status_code: non_neg_integer(),
          headers: Typespecs.headers(),
          body: Typespecs.body()
        }

  @type http_response_schema_t :: [unquote(NimbleOptions.option_typespec(@http_response_schema))]

  defstruct [:status_code, :headers, :body]

  @spec new(http_response_schema_t()) :: t()
  def new(opts) do
    opts = opts |> NimbleOptions.validate!(@http_response_schema)
    struct(__MODULE__, opts)
  end
end

defmodule ExWechatpay.Http.Default do
  @moduledoc """
  Implement ExWechatpay.Http behavior with Finch
  """

  require Logger
  alias ExWechatpay.{Http, Error}

  @behaviour Http

  # types
  @type t :: %__MODULE__{
          name: atom()
        }

  defstruct name: __MODULE__

  @impl Http
  def new(opts \\ []) do
    opts = opts |> Keyword.put_new(:name, __MODULE__)
    struct(__MODULE__, opts)
  end

  @impl Http
  def do_request(http, req) do
    with opts <- opts(req.opts),
         finch_req <-
           Finch.build(
             req.method,
             Http.Request.url(req),
             req.headers,
             req.body,
             opts
           ) do
      # Logger.debug(%{
      #   "method" => req.method,
      #   "url" => Http.Request.url(req) |> URI.to_string(),
      #   "params" => req.params,
      #   "headers" => req.headers,
      #   "body" => req.body,
      #   "opts" => opts,
      #   "req" => finch_req
      # })

      finch_req
      |> Finch.request(http.name)
      |> case do
        {:ok, %Finch.Response{status: status, body: body, headers: headers}}
        when status in 200..299 ->
          {:ok, Http.Response.new(status_code: status, body: body, headers: headers)}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, Error.new("status: #{status}, body: #{body}")}

        {:error, exception} ->
          raise exception
          {:error, Error.new(inspect(exception))}
      end
    end
  end

  defp opts(nil), do: [receive_timeout: 5000]
  defp opts(options), do: Keyword.put_new(options, :receive_timeout, 5000)

  def child_spec(opts) do
    http = Keyword.fetch!(opts, :http)
    %{id: {__MODULE__, http.name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl Http
  def start_link(opts) do
    {http, _opts} = Keyword.pop!(opts, :http)
    Finch.start_link(name: http.name)
  end
end
