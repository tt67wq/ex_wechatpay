defmodule ExWechatpay.Request do
  @moduledoc """
  微信支付请求Request
  """

  alias ExWechatpay.{Util}

  @request_schema [
    method: [
      type: :any,
      doc: "request method",
      required: true
    ],
    api: [
      type: :string,
      doc: "wechat pay api",
      required: true
    ],
    params: [
      type: {:map, :string, :string},
      doc: "request query params",
      default: %{}
    ],
    body: [
      type: :any,
      doc: "request body, json or xml",
      default: nil
    ]
  ]

  @type request_schema_t :: [unquote(NimbleOptions.option_typespec(@request_schema))]
  @type t :: %__MODULE__{}

  defstruct [
    :method,
    :api,
    :params,
    :body
  ]

  @spec new(request_schema_t()) :: t()
  def new(opts \\ []) do
    opts = opts |> NimbleOptions.validate!(@request_schema)
    %__MODULE__{} |> struct(opts)
  end

  @spec authorization(ExWechatpay.Client.t(), t()) :: String.t()
  def authorization(client, %{method: method, api: api, params: params, body: body}) do
    {http_method, body} =
      case method do
        :post -> {"POST", body}
        :get -> {"GET", ""}
      end

    url =
      api <>
        if params in [%{}, nil] do
          ""
        else
          "?" <> URI.encode_query(params)
        end

    ts = Util.timestamp()
    nonce_str = Util.random_string(12)

    string_to_sign = "#{http_method}\n#{url}\n#{ts}\n#{nonce_str}\n#{body}\n"

    signature =
      string_to_sign
      |> :public_key.sign(:sha256, client.client_key)
      |> Base.encode64()

    "WECHATPAY2-SHA256-RSA2048 " <>
      "mchid=\"#{client.mchid}\",nonce_str=\"#{nonce_str}\",timestamp=\"#{ts}\",serial_no=\"#{client.client_serial_no}\",signature=\"#{signature}\""
  end
end
