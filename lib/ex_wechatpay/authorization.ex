defmodule ExWechatpay.Authorization do
  @moduledoc false
  alias ExWechatpay.Typespecs
  alias ExWechatpay.Util

  @spec generate(
          ExWechatpay.Model.ConfigOption.t(),
          Typespecs.method(),
          Typespecs.api(),
          Typespecs.params(),
          Typespecs.body()
        ) :: String.t()
  @doc """
  Generate authorization string
  """
  def generate(config, method, api, params, body) do
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

    ts = System.system_time(:second)
    nonce_str = Util.random_string(12)

    string_to_sign = "#{http_method}\n#{url}\n#{ts}\n#{nonce_str}\n#{body}\n"

    signature =
      string_to_sign
      |> :public_key.sign(:sha256, config[:client_key])
      |> Base.encode64()

    "WECHATPAY2-SHA256-RSA2048 " <>
      "mchid=\"#{config[:mchid]}\",nonce_str=\"#{nonce_str}\",timestamp=\"#{ts}\",serial_no=\"#{config[:client_serial_no]}\",signature=\"#{signature}\""
  end
end
