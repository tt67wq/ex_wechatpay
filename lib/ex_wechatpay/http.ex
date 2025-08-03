defprotocol ExWechatpay.Http do
  @doc """
  Perform an HTTP request.
  """
  @spec do_request(
          http :: ExWechatpay.Http.t(),
          req :: ExWechatpay.Model.Http.Request.t()
        ) ::
          {:ok, ExWechatpay.Model.Http.Response.t()} | {:error, ExWechatpay.Exception.t()}
  def do_request(http, req)
end
