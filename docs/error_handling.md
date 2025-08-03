# 错误处理指南

本文档提供了使用 ExWechatpay SDK 时的错误处理最佳实践，帮助开发者更好地处理各种可能出现的错误情况。

## 目录

- [错误类型概述](#错误类型概述)
- [常见错误代码](#常见错误代码)
- [错误处理策略](#错误处理策略)
- [重试机制](#重试机制)
- [日志记录](#日志记录)
- [错误处理示例](#错误处理示例)

## 错误类型概述

在使用 ExWechatpay SDK 时，可能会遇到以下几类错误：

1. **请求构建错误**：在构建 HTTP 请求时出现的错误，如参数不正确、签名失败等
2. **网络错误**：网络连接问题、超时等
3. **微信支付业务错误**：由微信支付 API 返回的业务错误，如余额不足、订单已存在等
4. **响应解析错误**：解析微信支付 API 响应时出现的错误
5. **证书相关错误**：证书加载、验证等问题

所有这些错误都会以 `{:error, %ExWechatpay.Exception{}}` 的形式返回。`ExWechatpay.Exception` 结构包含了错误消息和详细信息：

```elixir
%ExWechatpay.Exception{
  message: "错误消息",  # 错误代码或描述
  details: %{...}      # 错误的详细信息
}
```

## 常见错误代码

以下是一些常见的微信支付 API 错误代码及其处理建议：

| 错误代码 | 说明 | 处理建议 |
| ------- | ---- | ------- |
| `INVALID_REQUEST` | 请求参数错误 | 检查请求参数是否符合要求 |
| `NOAUTH` | 商户无此接口权限 | 检查商户权限配置 |
| `NOTENOUGH` | 余额不足 | 提示用户余额不足 |
| `ORDERPAID` | 订单已支付 | 查询订单获取支付结果 |
| `ORDERCLOSED` | 订单已关闭 | 需要重新下单 |
| `SYSTEMERROR` | 系统错误 | 可以重试请求 |
| `SIGN_ERROR` | 签名错误 | 检查私钥和签名方法 |
| `LACK_PARAMS` | 缺少参数 | 检查请求参数是否完整 |
| `NOT_FOUND` | 资源不存在 | 检查资源标识符是否正确 |
| `INVALID_TRANSACTIONID` | 无效的订单号 | 检查订单号格式 |
| `ORDERNOTEXIST` | 订单不存在 | 检查订单号是否正确 |
| `BIZERR_NEED_RETRY` | 需要重试的业务错误 | 稍后重试 |
| `OPENID_MISMATCH` | OpenID不匹配 | 检查OpenID是否与商户号关联 |
| `REFUNDNOTEXIST` | 退款不存在 | 检查退款单号是否正确 |
| `PARAM_ERROR` | 参数错误 | 检查请求参数 |
| `FREQUENCY_LIMITED` | 频率限制 | 降低请求频率 |

## 错误处理策略

### 基本错误处理模式

使用 `case` 表达式处理操作结果：

```elixir
case MyWechat.create_native_transaction(params) do
  {:ok, result} ->
    # 处理成功结果
    Logger.info("支付创建成功: #{inspect(result)}")
    # 其他业务逻辑...
    
  {:error, %ExWechatpay.Exception{message: message, details: details}} ->
    # 处理错误
    Logger.error("支付创建失败: #{message}, 详情: #{inspect(details)}")
    # 错误处理逻辑...
end
```

### 分类处理特定错误

针对不同类型的错误采取不同的处理策略：

```elixir
case MyWechat.create_jsapi_transaction(params) do
  {:ok, result} ->
    # 处理成功结果
    
  {:error, %ExWechatpay.Exception{message: "SYSTEMERROR"}} ->
    # 系统错误，可以重试
    retry_payment(params)
    
  {:error, %ExWechatpay.Exception{message: "NOTENOUGH"}} ->
    # 余额不足，通知用户
    {:error, :insufficient_balance}
    
  {:error, %ExWechatpay.Exception{message: "ORDERPAID"}} ->
    # 订单已支付，查询订单状态
    MyWechat.query_transaction_by_out_trade_no(params["out_trade_no"])
    
  {:error, %ExWechatpay.Exception{message: "PARAM_ERROR", details: details}} ->
    # 参数错误，记录详细错误信息
    Logger.error("参数错误: #{inspect(details)}")
    {:error, :invalid_parameters}
    
  {:error, error} ->
    # 其他错误
    Logger.error("未知错误: #{inspect(error)}")
    {:error, :unknown_error}
end
```

### 使用 `with` 表达式处理多步操作

当需要执行多个依赖操作时，使用 `with` 表达式可以简化错误处理：

```elixir
with {:ok, transaction} <- MyWechat.create_native_transaction(params),
     code_url = transaction["code_url"],
     {:ok, qr_code} <- generate_qr_code(code_url),
     {:ok, _} <- save_order_info(order_id, transaction) do
  # 所有操作成功
  {:ok, %{qr_code: qr_code, transaction: transaction}}
else
  {:error, %ExWechatpay.Exception{message: message}} ->
    # 处理微信支付错误
    Logger.error("微信支付错误: #{message}")
    {:error, :payment_api_error}
    
  {:error, :qr_code_generation_failed} ->
    # 处理二维码生成错误
    Logger.error("二维码生成失败")
    {:error, :qr_code_error}
    
  {:error, :database_error} ->
    # 处理数据库错误
    Logger.error("保存订单信息失败")
    {:error, :database_error}
end
```

## 重试机制

对于某些临时性错误（如网络超时、系统错误等），实施重试机制可以提高系统的稳定性。

### 简单重试函数

```elixir
defmodule MyApp.PaymentRetry do
  require Logger
  
  @doc """
  使用指数退避算法重试支付操作
  
  ## 参数
    * `operation` - 要重试的函数
    * `max_attempts` - 最大重试次数，默认为 3
    * `initial_delay` - 初始延迟时间（毫秒），默认为 1000
  
  ## 返回值
    * `{:ok, result}` - 操作成功的结果
    * `{:error, error}` - 所有重试失败后的最后一个错误
  """
  def retry_with_backoff(operation, max_attempts \\ 3, initial_delay \\ 1000) do
    retry_with_backoff_internal(operation, max_attempts, initial_delay, 1, nil)
  end
  
  defp retry_with_backoff_internal(_operation, max_attempts, _delay, current_attempt, last_error)
       when current_attempt > max_attempts do
    # 达到最大重试次数
    {:error, last_error || %ExWechatpay.Exception{message: "max_retries_reached", details: nil}}
  end
  
  defp retry_with_backoff_internal(operation, max_attempts, delay, current_attempt, _last_error) do
    # 执行操作
    case operation.() do
      {:ok, result} ->
        # 操作成功
        {:ok, result}
        
      {:error, %ExWechatpay.Exception{message: message} = error} ->
        # 判断是否应该重试
        if retryable_error?(message) do
          # 计算下次重试延迟（指数退避）
          next_delay = delay * 2
          
          # 添加一些随机抖动，避免多个请求同时重试
          jitter = :rand.uniform(div(delay, 4))
          actual_delay = next_delay + jitter
          
          Logger.warn("操作失败，将在 #{actual_delay}ms 后重试 (#{current_attempt}/#{max_attempts}): #{message}")
          
          # 等待后重试
          :timer.sleep(actual_delay)
          retry_with_backoff_internal(operation, max_attempts, next_delay, current_attempt + 1, error)
        else
          # 不可重试的错误
          Logger.error("操作失败，不可重试的错误: #{message}")
          {:error, error}
        end
    end
  end
  
  # 判断错误是否可重试
  defp retryable_error?(message) do
    # 可重试的错误类型
    retryable_errors = [
      "SYSTEMERROR",
      "BIZERR_NEED_RETRY",
      "FREQUENCY_LIMITED",
      "RESOURCE_UNAVAILABLE"
    ]
    
    message in retryable_errors
  end
end
```

### 使用重试机制

```elixir
alias MyApp.PaymentRetry

# 创建支付订单并自动重试
def create_payment_with_retry(params) do
  operation = fn -> MyWechat.create_native_transaction(params) end
  
  case PaymentRetry.retry_with_backoff(operation, 3, 1000) do
    {:ok, result} ->
      # 最终成功
      {:ok, result}
      
    {:error, error} ->
      # 重试后仍然失败
      Logger.error("创建支付失败，已重试 3 次: #{inspect(error)}")
      {:error, :payment_creation_failed}
  end
end
```

## 日志记录

适当的日志记录对于排查问题至关重要。建议在错误处理中添加详细的日志记录：

```elixir
defmodule MyApp.PaymentLogger do
  require Logger
  
  # 日志级别常量
  @info :info
  @warn :warn
  @error :error
  
  @doc """
  记录支付相关日志
  """
  def log(level, message, metadata \\ %{}) do
    # 确保元数据是 map
    metadata = if is_map(metadata), do: metadata, else: %{data: metadata}
    
    # 格式化元数据
    formatted_metadata =
      metadata
      |> maybe_redact_sensitive_data()
      |> Map.put(:service, "wechat_pay")
      |> Map.put(:timestamp, DateTime.utc_now())
    
    # 记录日志
    case level do
      @info -> Logger.info("#{message}", formatted_metadata)
      @warn -> Logger.warning("#{message}", formatted_metadata)
      @error -> Logger.error("#{message}", formatted_metadata)
      _ -> Logger.debug("#{message}", formatted_metadata)
    end
  end
  
  @doc """
  记录支付操作日志
  """
  def log_payment_operation(operation, params, result) do
    # 提取订单号
    order_id = params["out_trade_no"] || "unknown"
    
    case result do
      {:ok, response} ->
        log(@info, "支付操作成功: #{operation}", %{
          order_id: order_id,
          operation: operation,
          response: response
        })
        
      {:error, %ExWechatpay.Exception{message: message, details: details}} ->
        log(@error, "支付操作失败: #{operation}", %{
          order_id: order_id,
          operation: operation,
          error_message: message,
          error_details: details
        })
    end
    
    # 返回原始结果，不影响函数调用链
    result
  end
  
  # 脱敏敏感数据
  defp maybe_redact_sensitive_data(metadata) do
    metadata
    |> redact_key_if_exists("certificate")
    |> redact_key_if_exists("apiv3_key")
    |> redact_key_if_exists("client_key")
    |> redact_key_if_exists("client_cert")
  end
  
  defp redact_key_if_exists(map, key) do
    if Map.has_key?(map, key) do
      Map.put(map, key, "[REDACTED]")
    else
      map
    end
  end
end
```

使用日志记录器：

```elixir
alias MyApp.PaymentLogger

def process_payment(params) do
  # 记录开始处理支付
  PaymentLogger.log(:info, "开始处理支付", %{params: params})
  
  # 执行支付操作并记录结果
  result = MyWechat.create_native_transaction(params)
  PaymentLogger.log_payment_operation("create_native_transaction", params, result)
  
  # 后续处理...
  case result do
    {:ok, response} ->
      # 成功处理...
      
    {:error, error} ->
      # 错误处理...
  end
end
```

## 错误处理示例

以下是一些常见场景的错误处理示例：

### 1. 创建支付订单

```elixir
defmodule MyApp.PaymentService do
  require Logger
  alias MyApp.PaymentRetry
  alias MyApp.PaymentLogger
  
  @doc """
  创建支付订单并处理各种可能的错误
  """
  def create_payment(params) do
    # 验证参数
    with :ok <- validate_payment_params(params) do
      # 创建操作函数
      operation = fn -> MyWechat.create_native_transaction(params) end
      
      # 使用重试机制
      case PaymentRetry.retry_with_backoff(operation, 3, 1000) do
        {:ok, result} ->
          # 成功创建支付
          PaymentLogger.log(:info, "支付订单创建成功", %{
            order_id: params["out_trade_no"],
            result: result
          })
          
          {:ok, result}
          
        {:error, %ExWechatpay.Exception{message: "ORDERPAID"}} ->
          # 订单已支付，查询订单状态
          PaymentLogger.log(:warn, "订单已支付，查询详情", %{order_id: params["out_trade_no"]})
          MyWechat.query_transaction_by_out_trade_no(params["out_trade_no"])
          
        {:error, %ExWechatpay.Exception{message: "ORDERCLOSED"}} ->
          # 订单已关闭
          PaymentLogger.log(:warn, "订单已关闭", %{order_id: params["out_trade_no"]})
          {:error, :order_closed}
          
        {:error, %ExWechatpay.Exception{message: "NOTENOUGH"}} ->
          # 余额不足
          PaymentLogger.log(:warn, "余额不足", %{order_id: params["out_trade_no"]})
          {:error, :insufficient_balance}
          
        {:error, %ExWechatpay.Exception{message: message, details: details}} ->
          # 其他微信支付错误
          PaymentLogger.log(:error, "支付创建失败", %{
            order_id: params["out_trade_no"],
            error_code: message,
            details: details
          })
          
          {:error, :payment_creation_failed, message}
      end
    else
      {:error, reason} ->
        # 参数验证失败
        PaymentLogger.log(:error, "支付参数验证失败", %{
          params: params,
          reason: reason
        })
        
        {:error, :invalid_parameters, reason}
    end
  end
  
  # 验证支付参数
  defp validate_payment_params(params) do
    required_fields = ["description", "out_trade_no", "amount"]
    
    # 检查必填字段
    missing_fields =
      required_fields
      |> Enum.filter(fn field -> !Map.has_key?(params, field) end)
    
    if Enum.empty?(missing_fields) do
      # 验证金额
      case params["amount"] do
        %{"total" => total} when is_integer(total) and total > 0 ->
          :ok
          
        _ ->
          {:error, "无效的金额参数"}
      end
    else
      {:error, "缺少必填字段: #{Enum.join(missing_fields, ", ")}"}
    end
  end
end
```

### 2. 查询订单状态

```elixir
defmodule MyApp.OrderService do
  alias MyApp.PaymentLogger
  
  @doc """
  查询订单状态并处理可能的错误
  """
  def query_order_status(out_trade_no) do
    PaymentLogger.log(:info, "查询订单状态", %{order_id: out_trade_no})
    
    case MyWechat.query_transaction_by_out_trade_no(out_trade_no) do
      {:ok, order_info} ->
        # 提取交易状态
        trade_state = order_info["trade_state"]
        trade_state_desc = order_info["trade_state_desc"]
        
        PaymentLogger.log(:info, "订单状态查询成功", %{
          order_id: out_trade_no,
          trade_state: trade_state,
          trade_state_desc: trade_state_desc
        })
        
        {:ok, %{state: trade_state, description: trade_state_desc, details: order_info}}
        
      {:error, %ExWechatpay.Exception{message: "NOT_FOUND"}} ->
        # 订单不存在
        PaymentLogger.log(:warn, "订单不存在", %{order_id: out_trade_no})
        {:error, :order_not_found}
        
      {:error, %ExWechatpay.Exception{message: "ORDERNOTEXIST"}} ->
        # 订单不存在
        PaymentLogger.log(:warn, "订单不存在", %{order_id: out_trade_no})
        {:error, :order_not_found}
        
      {:error, %ExWechatpay.Exception{message: "INVALID_REQUEST"}} ->
        # 无效的请求
        PaymentLogger.log(:error, "查询订单请求无效", %{order_id: out_trade_no})
        {:error, :invalid_request}
        
      {:error, error} ->
        # 其他错误
        PaymentLogger.log(:error, "查询订单失败", %{
          order_id: out_trade_no,
          error: error
        })
        
        {:error, :query_failed}
    end
  end
end
```

### 3. 申请退款

```elixir
defmodule MyApp.RefundService do
  alias MyApp.PaymentLogger
  alias MyApp.PaymentRetry
  
  @doc """
  申请退款并处理可能的错误
  """
  def create_refund(params) do
    # 验证退款参数
    with :ok <- validate_refund_params(params) do
      PaymentLogger.log(:info, "开始申请退款", %{
        refund_no: params["out_refund_no"],
        order_id: params["out_trade_no"] || params["transaction_id"]
      })
      
      # 创建操作函数
      operation = fn -> MyWechat.create_refund(params) end
      
      # 使用重试机制
      case PaymentRetry.retry_with_backoff(operation, 2, 1000) do
        {:ok, result} ->
          # 退款申请成功
          PaymentLogger.log(:info, "退款申请成功", %{
            refund_no: params["out_refund_no"],
            refund_id: result["refund_id"],
            status: result["status"]
          })
          
          {:ok, result}
          
        {:error, %ExWechatpay.Exception{message: "USER_ACCOUNT_ABNORMAL"}} ->
          # 用户账户异常
          PaymentLogger.log(:error, "用户账户异常", %{
            refund_no: params["out_refund_no"]
          })
          
          {:error, :user_account_abnormal}
          
        {:error, %ExWechatpay.Exception{message: "NOTENOUGH"}} ->
          # 余额不足
          PaymentLogger.log(:error, "余额不足，无法退款", %{
            refund_no: params["out_refund_no"]
          })
          
          {:error, :insufficient_balance}
          
        {:error, %ExWechatpay.Exception{message: "INVALID_REQUEST", details: details}} ->
          # 请求无效
          PaymentLogger.log(:error, "退款请求无效", %{
            refund_no: params["out_refund_no"],
            details: details
          })
          
          {:error, :invalid_request}
          
        {:error, %ExWechatpay.Exception{message: "REFUNDNOTEXIST"}} ->
          # 退款单号不存在
          PaymentLogger.log(:error, "退款单号不存在", %{
            refund_no: params["out_refund_no"]
          })
          
          {:error, :refund_not_exist}
          
        {:error, error} ->
          # 其他错误
          PaymentLogger.log(:error, "申请退款失败", %{
            refund_no: params["out_refund_no"],
            error: error
          })
          
          {:error, :refund_failed}
      end
    else
      {:error, reason} ->
        # 参数验证失败
        PaymentLogger.log(:error, "退款参数验证失败", %{
          params: params,
          reason: reason
        })
        
        {:error, :invalid_parameters, reason}
    end
  end
  
  # 验证退款参数
  defp validate_refund_params(params) do
    # 检查退款单号
    if !Map.has_key?(params, "out_refund_no") do
      {:error, "缺少退款单号 (out_refund_no)"}
    else
      # 检查订单号（商户订单号和微信支付订单号二选一）
      has_out_trade_no = Map.has_key?(params, "out_trade_no")
      has_transaction_id = Map.has_key?(params, "transaction_id")
      
      if !has_out_trade_no && !has_transaction_id do
        {:error, "商户订单号 (out_trade_no) 和微信支付订单号 (transaction_id) 必须提供一个"}
      else
        # 检查退款金额
        case params["amount"] do
          %{"refund" => refund, "total" => total}
          when is_integer(refund) and is_integer(total) and refund > 0 and total >= refund ->
            :ok
            
          _ ->
            {:error, "无效的退款金额参数"}
        end
      end
    end
  end
end
```

### 4. 全局错误处理中间件（Phoenix 示例）

```elixir
defmodule MyAppWeb.WechatPayErrorHandler do
  @moduledoc """
  处理微信支付相关错误的中间件
  """
  
  import Plug.Conn
  import Phoenix.Controller
  
  alias MyApp.PaymentLogger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    # 注册错误处理
    register_before_send(conn, &handle_errors/1)
  end
  
  # 处理错误
  defp handle_errors(%{status: status, assigns: %{reason: reason}} = conn) when status >= 400 do
    # 提取错误信息
    error_info = extract_error_info(reason)
    
    # 记录错误日志
    PaymentLogger.log(:error, "API 错误", %{
      path: conn.request_path,
      status: status,
      error: error_info
    })
    
    # 构造错误响应
    error_response = %{
      error: %{
        code: error_info.code,
        message: error_info.message,
        details: error_info.details
      }
    }
    
    # 返回 JSON 格式的错误响应
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(error_response))
  end
  
  defp handle_errors(conn), do: conn
  
  # 提取错误信息
  defp extract_error_info(%ExWechatpay.Exception{message: message, details: details}) do
    # 处理微信支付错误
    %{
      code: String.downcase(message),
      message: get_error_message(message),
      details: details
    }
  end
  
  defp extract_error_info({:error, :invalid_parameters, reason}) do
    # 处理参数错误
    %{
      code: "invalid_parameters",
      message: "参数无效",
      details: reason
    }
  end
  
  defp extract_error_info(error) do
    # 处理其他错误
    %{
      code: "unknown_error",
      message: "未知错误",
      details: inspect(error)
    }
  end
  
  # 获取错误消息
  defp get_error_message(code) do
    # 错误代码映射表
    error_messages = %{
      "SYSTEMERROR" => "系统错误，请稍后再试",
      "ORDERNOTEXIST" => "订单不存在",
      "ORDERPAID" => "订单已支付",
      "ORDERCLOSED" => "订单已关闭",
      "NOTENOUGH" => "余额不足",
      "INVALID_REQUEST" => "无效的请求",
      "PARAM_ERROR" => "参数错误",
      "FREQUENCY_LIMITED" => "请求频率过高，请稍后再试",
      "USER_ACCOUNT_ABNORMAL" => "用户账户异常",
      "REFUNDNOTEXIST" => "退款单号不存在"
    }
    
    # 查找错误消息，如果没有找到则使用原始代码
    Map.get(error_messages, code, "微信支付错误: #{code}")
  end
end
```

在 Phoenix 路由中使用错误处理中间件：

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  
  # 微信支付 API 管道
  pipeline :wechat_pay_api do
    plug :accepts, ["json"]
    plug MyAppWeb.WechatPayErrorHandler
  end
  
  # 微信支付相关路由
  scope "/api/wechat_pay", MyAppWeb do
    pipe_through :wechat_pay_api
    
    post "/payments", PaymentController, :create
    get "/payments/:out_trade_no", PaymentController, :show
    post "/refunds", RefundController, :create
    get "/refunds/:out_refund_no", RefundController, :show
  end
end
```

通过以上示例，您可以在应用中实现全面而健壮的错误处理机制，提高应用的稳定性和用户体验。