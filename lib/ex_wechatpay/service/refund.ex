defmodule ExWechatpay.Service.Refund do
  @moduledoc """
  退款服务模块

  该模块负责处理微信支付的退款相关操作，包括创建退款、查询退款等。
  通过集中管理退款逻辑，提高了代码的可维护性和一致性。
  """

  alias ExWechatpay.Core.RequestBuilder
  alias ExWechatpay.Core.ResponseHandler
  alias ExWechatpay.Core.SignatureManager
  alias ExWechatpay.Exception
  alias ExWechatpay.Model.ConfigOption
  alias ExWechatpay.Typespecs

  @doc """
  创建退款

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `args` - 退款参数，必须包含以下字段：
      * `out_refund_no` - 商户退款单号
      * `out_trade_no` 或 `transaction_id` - 商户订单号或微信支付订单号
      * `amount` - 退款金额信息，包含 `refund` 字段表示退款金额

  ## 返回值
    * `{:ok, map()}` - 成功创建的退款信息
    * `{:error, Exception.t()}` - 创建退款失败的错误信息
  """
  @spec create_refund(
          ConfigOption.t(),
          Typespecs.name(),
          Typespecs.refund_req()
        ) ::
          Typespecs.result_t(Typespecs.refund_resp())
  def create_refund(config, finch, args) do
    {:ok, body} = RequestBuilder.extend_args(config, args)
    request = RequestBuilder.build_request(config, :post, "/v3/refund/domestic/refunds", %{}, body)

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request) do
      ResponseHandler.verify_and_parse_response(config, resp)
    end
  end

  @doc """
  查询退款

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `out_refund_no` - 商户退款单号

  ## 返回值
    * `{:ok, map()}` - 退款信息
    * `{:error, Exception.t()}` - 查询失败的错误信息
  """
  @spec query_refund(ConfigOption.t(), Typespecs.name(), String.t()) ::
          Typespecs.result_t(Typespecs.refund_query_resp())
  def query_refund(config, finch, out_refund_no) do
    request =
      RequestBuilder.build_request(
        config,
        :get,
        "/v3/refund/domestic/refunds/#{out_refund_no}",
        %{},
        nil
      )

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request) do
      ResponseHandler.verify_and_parse_response(config, resp)
    end
  end

  @doc """
  申请退款回调通知处理

  ## 参数
    * `config` - 配置选项
    * `headers` - 回调请求头
    * `body` - 回调请求体

  ## 返回值
    * `{:ok, map()}` - 解析后的回调数据
    * `{:error, Exception.t()}` - 处理失败的错误信息
  """
  @spec handle_refund_notification(
          ConfigOption.t(),
          Typespecs.headers(),
          Typespecs.body()
        ) ::
          Typespecs.result_t(Typespecs.payment_notification())
  def handle_refund_notification(config, headers, body) do
    with true <- SignatureManager.verify_signature(config, headers, body),
         {:ok, decoded} <- Jason.decode(body),
         %{"resource" => encrypted_resource} <- decoded,
         decrypted_data = ResponseHandler.decrypt(config, encrypted_resource),
         {:ok, resource_data} <- Jason.decode(decrypted_data) do
      {:ok, Map.put(decoded, "resource", resource_data)}
    else
      false ->
        {:error, Exception.new("invalid_signature", %{"headers" => headers, "body" => body})}

      {:error, %Jason.DecodeError{} = error} ->
        {:error, Exception.new("json_decode_error", error)}

      error ->
        {:error, Exception.new("refund_notification_error", error)}
    end
  end
end
