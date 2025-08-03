defmodule ExWechatpay.Service.Transaction do
  @moduledoc """
  交易服务模块

  该模块负责处理微信支付的交易相关操作，包括创建交易、查询交易和关闭交易等。
  通过集中管理交易逻辑，提高了代码的可维护性和一致性。
  """

  alias ExWechatpay.Core.RequestBuilder
  alias ExWechatpay.Core.ResponseHandler
  alias ExWechatpay.Model.ConfigOption
  alias ExWechatpay.Typespecs

  @doc """
  创建 Native 支付交易

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `args` - 交易参数

  ## 返回值
    * `{:ok, map()}` - 成功创建的交易信息
    * `{:error, Exception.t()}` - 创建交易失败的错误信息
  """
  @spec create_native_transaction(
          ConfigOption.t(),
          Typespecs.name(),
          Typespecs.native_transaction_req()
        ) ::
          Typespecs.result_t(Typespecs.native_transaction_resp())
  def create_native_transaction(config, finch, args) do
    {:ok, body} = RequestBuilder.extend_args(config, args)
    request = RequestBuilder.build_request(config, :post, "/v3/pay/transactions/native", %{}, body)

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request) do
      ResponseHandler.verify_and_parse_response(config, resp)
    end
  end

  @doc """
  创建 JSAPI 支付交易

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `args` - 交易参数

  ## 返回值
    * `{:ok, map()}` - 成功创建的交易信息
    * `{:error, Exception.t()}` - 创建交易失败的错误信息
  """
  @spec create_jsapi_transaction(
          ConfigOption.t(),
          Typespecs.name(),
          Typespecs.jsapi_transaction_req()
        ) ::
          Typespecs.result_t(Typespecs.jsapi_transaction_resp())
  def create_jsapi_transaction(config, finch, args) do
    {:ok, body} = RequestBuilder.extend_args(config, args)
    request = RequestBuilder.build_request(config, :post, "/v3/pay/transactions/jsapi", %{}, body)

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request) do
      ResponseHandler.verify_and_parse_response(config, resp)
    end
  end

  @doc """
  创建 H5 支付交易

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `args` - 交易参数

  ## 返回值
    * `{:ok, map()}` - 成功创建的交易信息
    * `{:error, Exception.t()}` - 创建交易失败的错误信息
  """
  @spec create_h5_transaction(
          ConfigOption.t(),
          Typespecs.name(),
          Typespecs.h5_transaction_req()
        ) ::
          Typespecs.result_t(Typespecs.h5_transaction_resp())
  def create_h5_transaction(config, finch, args) do
    {:ok, body} = RequestBuilder.extend_args(config, args)
    request = RequestBuilder.build_request(config, :post, "/v3/pay/transactions/h5", %{}, body)

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request) do
      ResponseHandler.verify_and_parse_response(config, resp)
    end
  end

  @doc """
  通过商户订单号查询交易

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `out_trade_no` - 商户订单号

  ## 返回值
    * `{:ok, map()}` - 交易信息
    * `{:error, Exception.t()}` - 查询失败的错误信息
  """
  @spec query_transaction_by_out_trade_no(ConfigOption.t(), Typespecs.name(), String.t()) ::
          Typespecs.result_t(Typespecs.transaction_query_resp())
  def query_transaction_by_out_trade_no(config, finch, out_trade_no) do
    request =
      RequestBuilder.build_request(
        config,
        :get,
        "/v3/pay/transactions/out-trade-no/#{out_trade_no}",
        %{"mchid" => config[:mchid]},
        nil
      )

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request) do
      ResponseHandler.verify_and_parse_response(config, resp)
    end
  end

  @doc """
  通过微信支付订单号查询交易

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `transaction_id` - 微信支付订单号

  ## 返回值
    * `{:ok, map()}` - 交易信息
    * `{:error, Exception.t()}` - 查询失败的错误信息
  """
  @spec query_transaction_by_transaction_id(ConfigOption.t(), Typespecs.name(), String.t()) ::
          Typespecs.result_t(Typespecs.transaction_query_resp())
  def query_transaction_by_transaction_id(config, finch, transaction_id) do
    request =
      RequestBuilder.build_request(
        config,
        :get,
        "/v3/pay/transactions/id/#{transaction_id}",
        %{"mchid" => config[:mchid]},
        nil
      )

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request) do
      ResponseHandler.verify_and_parse_response(config, resp)
    end
  end

  @doc """
  关闭交易

  ## 参数
    * `config` - 配置选项
    * `finch` - Finch 实例
    * `out_trade_no` - 商户订单号

  ## 返回值
    * `:ok` - 关闭成功
    * `{:error, Exception.t()}` - 关闭失败的错误信息
  """
  @spec close_transaction(ConfigOption.t(), Typespecs.name(), String.t()) :: :ok | Typespecs.err_t()
  def close_transaction(config, finch, out_trade_no) do
    {:ok, body} = Jason.encode(%{"mchid" => config[:mchid]})

    request =
      RequestBuilder.build_request(
        config,
        :post,
        "/v3/pay/transactions/out-trade-no/#{out_trade_no}/close",
        %{},
        body
      )

    with {:ok, resp} <- ExWechatpay.Http.do_request(finch, request),
         {:ok, _} <- ResponseHandler.verify_and_parse_response(config, resp) do
      :ok
    end
  end
end
