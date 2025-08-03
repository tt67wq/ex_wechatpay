defprotocol ExWechatpay.Http do
  @moduledoc """
  HTTP 请求处理协议

  该协议定义了执行 HTTP 请求的接口。
  通过实现该协议，可以支持不同的 HTTP 客户端库。
  目前默认使用 Finch 作为 HTTP 客户端。
  """

  alias ExWechatpay.Model.Http.Request
  alias ExWechatpay.Model.Http.Response
  alias ExWechatpay.Typespecs

  @doc """
  执行 HTTP 请求

  ## 参数
    * `http` - HTTP 客户端实例
    * `req` - HTTP 请求

  ## 返回值
    * `{:ok, Response.t()}` - 请求成功的响应
    * `{:error, Exception.t()}` - 请求失败的错误信息
  """
  @spec do_request(
          http :: ExWechatpay.Http.t(),
          req :: Request.t()
        ) ::
          Typespecs.result_t(Response.t())
  def do_request(http, req)
end
