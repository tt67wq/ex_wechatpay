defmodule ExWechatpay.Http do
  @moduledoc """
  behavior os http transport
  """
  alias ExWechatpay.Exception
  alias ExWechatpay.Model.Http
  alias ExWechatpay.Typespecs

  @callback do_request(
              name :: pid() | {atom(), node()} | Typespecs.name(),
              req :: Http.Request.t()
            ) ::
              {:ok, Http.Response.t()} | {:error, Exception.t()}
end

defmodule ExWechatpay.Http.Finch do
  @moduledoc """
  Implement ExWechatpay.Http behavior with Finch
  """

  @behaviour ExWechatpay.Http

  use Agent

  alias ExWechatpay.Exception
  alias ExWechatpay.Model.Http

  require Logger

  def start_link({finch_name, agent_name}) do
    Agent.start_link(fn -> finch_name end, name: agent_name)
  end

  defp opts(nil), do: [receive_timeout: 5000]
  defp opts(options), do: Keyword.put_new(options, :receive_timeout, 5000)

  @impl ExWechatpay.Http
  def do_request(agent_name, req) do
    Agent.get(agent_name, __MODULE__, :handle_do_request, [req])
  end

  def handle_do_request(finch_name, req) do
    opts = opts(req.opts)

    finch_req =
      Finch.build(
        req.method,
        Http.Request.url(req),
        req.headers,
        req.body,
        opts
      )

    finch_req
    |> Finch.request(finch_name)
    |> case do
      {:ok, %Finch.Response{status: status, body: body, headers: headers}}
      when status in 200..299 ->
        {:ok, %Http.Response{status_code: status, body: body, headers: headers}}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, Exception.new("bad response", %{status: status, body: body})}

      {:error, exception} ->
        {:error, Exception.new("bad response", exception)}
    end
  end
end
