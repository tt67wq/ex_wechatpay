# 高级使用指南

本文档提供了 ExWechatpay SDK 的高级使用指南和最佳实践，帮助开发者更好地使用 SDK 完成微信支付相关功能。

## 目录

- [异步通知处理](#异步通知处理)
- [证书管理](#证书管理)
- [错误处理与重试策略](#错误处理与重试策略)
- [自定义配置](#自定义配置)
- [多商户支持](#多商户支持)
- [沙箱环境](#沙箱环境)
- [完整支付流程示例](#完整支付流程示例)

## 异步通知处理

微信支付会通过异步通知的方式将支付结果、退款结果等信息推送给商户。正确处理这些通知是保证业务准确性的关键。

### 支付结果通知

```elixir
defmodule MyAppWeb.WechatPayController do
  use MyAppWeb, :controller
  require Logger
  
  # 支付结果通知处理
  def payment_notify(conn, _params) do
    # 1. 读取请求体和请求头
    {:ok, body, conn} = read_body(conn)
    headers = Enum.map(conn.req_headers, fn {k, v} -> {k, v} end)
    
    # 2. 验证签名
    if MyWechat.verify(headers, body) do
      # 3. 解析通知数据
      case Jason.decode(body) do
        {:ok, notification} ->
          # 4. 获取资源数据并解密（如果需要）
          resource = notification["resource"]
          resource_type = notification["resource_type"]
          
          if resource_type == "encrypt-resource" do
            case MyWechat.decrypt(resource) do
              {:ok, decrypted_data} ->
                case Jason.decode(decrypted_data) do
                  {:ok, payment_data} ->
                    # 5. 处理支付结果
                    handle_payment_result(payment_data)
                    
                    # 6. 返回成功响应
                    json_response(conn, 200, %{code: "SUCCESS", message: "成功"})
                    
                  {:error, _} ->
                    Logger.error("解析解密后的数据失败")
                    json_response(conn, 500, %{code: "FAIL", message: "解析解密后的数据失败"})
                end
                
              {:error, error} ->
                Logger.error("解密数据失败: #{inspect(error)}")
                json_response(conn, 500, %{code: "FAIL", message: "解密数据失败"})
            end
          else
            # 数据未加密，直接处理
            handle_payment_result(resource)
            json_response(conn, 200, %{code: "SUCCESS", message: "成功"})
          end
          
        {:error, _} ->
          Logger.error("解析通知数据失败")
          json_response(conn, 400, %{code: "FAIL", message: "解析通知数据失败"})
      end
    else
      # 签名验证失败
      Logger.warn("通知签名验证失败")
      json_response(conn, 401, %{code: "FAIL", message: "签名验证失败"})
    end
  end
  
  # 退款结果通知处理
  def refund_notify(conn, _params) do
    {:ok, body, conn} = read_body(conn)
    headers = Enum.map(conn.req_headers, fn {k, v} -> {k, v} end)
    
    # 使用 SDK 提供的退款通知处理函数，自动完成验签和解密
    case MyWechat.handle_refund_notification(headers, body) do
      {:ok, notification} ->
        # 处理退款结果
        refund_status = get_in(notification, ["resource", "status"])
        out_refund_no = get_in(notification, ["resource", "out_refund_no"])
        
        # 更新业务系统中的退款状态
        case update_refund_status(out_refund_no, refund_status) do
          :ok ->
            json_response(conn, 200, %{code: "SUCCESS", message: "成功"})
            
          {:error, reason} ->
            Logger.error("更新退款状态失败: #{reason}")
            json_response(conn, 500, %{code: "FAIL", message: "处理退款结果失败"})
        end
        
      {:error, error} ->
        Logger.error("处理退款通知失败: #{inspect(error)}")
        json_response(conn, 400, %{code: "FAIL", message: "处理退款通知失败"})
    end
  end
  
  # 处理支付结果
  defp handle_payment_result(payment_data) do
    # 从 payment_data 中提取关键信息
    out_trade_no = payment_data["out_trade_no"]
    transaction_id = payment_data["transaction_id"]
    trade_state = payment_data["trade_state"]
    
    # 根据 trade_state 更新订单状态
    case trade_state do
      "SUCCESS" ->
        # 支付成功
        update_order_status(out_trade_no, :paid, transaction_id)
        
      "REFUND" ->
        # 转入退款
        update_order_status(out_trade_no, :refunding, transaction_id)
        
      "NOTPAY" ->
        # 未支付
        update_order_status(out_trade_no, :pending, transaction_id)
        
      "CLOSED" ->
        # 已关闭
        update_order_status(out_trade_no, :closed, transaction_id)
        
      "USERPAYING" ->
        # 用户支付中
        update_order_status(out_trade_no, :processing, transaction_id)
        
      "PAYERROR" ->
        # 支付失败
        update_order_status(out_trade_no, :failed, transaction_id)
        
      _ ->
        # 其他状态
        Logger.warn("未处理的支付状态: #{trade_state}")
    end
  end
  
  # 更新订单状态（示例）
  defp update_order_status(out_trade_no, status, transaction_id) do
    # 实际业务中，这里应该更新数据库中的订单状态
    Logger.info("更新订单 #{out_trade_no} 状态为 #{status}，微信支付订单号: #{transaction_id}")
  end
  
  # 更新退款状态（示例）
  defp update_refund_status(out_refund_no, status) do
    # 实际业务中，这里应该更新数据库中的退款状态
    Logger.info("更新退款单 #{out_refund_no} 状态为 #{status}")
    :ok
  end
  
  # JSON 响应辅助函数
  defp json_response(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
```

### 配置回调路由

在 Phoenix 项目中，需要在路由文件中配置回调路径：

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  
  # ...
  
  scope "/api", MyAppWeb do
    pipe_through :api
    
    # 微信支付回调路由
    post "/wechat_pay/payment_notify", WechatPayController, :payment_notify
    post "/wechat_pay/refund_notify", WechatPayController, :refund_notify
  end
end
```

## 证书管理

微信支付平台证书会定期更新，正确管理证书是确保支付通知验签正常工作的关键。

### 初始化证书

首次使用 SDK 时，需要获取并配置微信支付平台证书：

```elixir
# 获取平台证书
{:ok, certificates} = MyWechat.get_certificates()

# 更新配置中的证书信息
cert_list = Enum.map(certificates["data"], fn cert ->
  {cert["serial_no"], cert["certificate"]}
end)

MyWechat.update_config(wx_pubs: cert_list)
```

### 自动更新证书

为避免证书过期导致验签失败，建议启用自动更新证书功能：

```elixir
# 在应用启动时启用自动更新证书
# Application 模块的 start/2 函数中
def start(_type, _args) do
  children = [
    # 其他子进程
    MyWechat
  ]
  
  # 启动子进程
  {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)
  
  # 启用自动更新证书（每天更新一次）
  MyWechat.enable_auto_update_certificates()
  
  {:ok, pid}
end
```

### 手动更新证书

如果不想使用自动更新，也可以通过定时任务手动更新证书：

```elixir
# 创建一个定时任务模块
defmodule MyApp.CertUpdateTask do
  use GenServer
  require Logger
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end
  
  @impl true
  def init(state) do
    # 启动后立即执行一次更新
    schedule_update()
    {:ok, state}
  end
  
  @impl true
  def handle_info(:update_certificates, state) do
    Logger.info("开始更新微信支付平台证书")
    
    case MyWechat.update_certificates() do
      {:ok, _} ->
        Logger.info("微信支付平台证书更新成功")
      {:error, error} ->
        Logger.error("微信支付平台证书更新失败: #{inspect(error)}")
    end
    
    # 安排下一次更新（24小时后）
    schedule_update()
    {:noreply, state}
  end
  
  defp schedule_update do
    # 24小时 = 24 * 60 * 60 * 1000 毫秒
    Process.send_after(self(), :update_certificates, 24 * 60 * 60 * 1000)
  end
end

# 将此模块添加到应用的监督树中
children = [
  # 其他子进程
  MyApp.CertUpdateTask
]
```

## 错误处理与重试策略

微信支付 API 调用可能因网络问题、服务器繁忙等原因失败，适当的错误处理和重试策略可以提高系统稳定性。

### 全局错误处理

```elixir
defmodule MyApp.WechatPayService do
  require Logger
  
  @doc """
  创建支付订单并处理可能的错误
  """
  def create_payment(params) do
    case MyWechat.create_native_transaction(params) do
      {:ok, result} ->
        {:ok, result}
        
      {:error, %ExWechatpay.Exception{message: "SYSTEMERROR", details: details}} ->
        # 系统错误，可以重试
        Logger.warn("微信支付系统错误，准备重试: #{inspect(details)}")
        retry_create_payment(params, 3)
        
      {:error, %ExWechatpay.Exception{message: "PARAM_ERROR", details: details}} ->
        # 参数错误，需要修正参数
        Logger.error("微信支付参数错误: #{inspect(details)}")
        {:error, :invalid_params}
        
      {:error, %ExWechatpay.Exception{message: "INVALID_REQUEST", details: details}} ->
        # 无效请求
        Logger.error("微信支付无效请求: #{inspect(details)}")
        {:error, :invalid_request}
        
      {:error, %ExWechatpay.Exception{message: "RESOURCE_ALREADY_EXISTS", details: details}} ->
        # 资源已存在，可能是重复请求
        Logger.warn("微信支付资源已存在: #{inspect(details)}")
        
        # 查询订单获取之前创建的信息
        out_trade_no = params["out_trade_no"]
        MyWechat.query_transaction_by_out_trade_no(out_trade_no)
        
      {:error, error} ->
        # 其他错误
        Logger.error("微信支付未知错误: #{inspect(error)}")
        {:error, :unknown_error}
    end
  end
  
  @doc """
  使用递减重试次数的方式重试创建支付
  """
  def retry_create_payment(_params, 0) do
    {:error, :max_retries_reached}
  end
  
  def retry_create_payment(params, retries) do
    # 等待一段时间后重试
    :timer.sleep(1000)
    
    case MyWechat.create_native_transaction(params) do
      {:ok, result} ->
        {:ok, result}
        
      {:error, _} ->
        Logger.warn("重试创建支付失败，剩余重试次数: #{retries - 1}")
        retry_create_payment(params, retries - 1)
    end
  end
end
```

### 使用 Task.Supervisor 异步处理支付

对于需要高并发处理的场景，可以使用 Task.Supervisor 异步处理支付请求：

```elixir
defmodule MyApp.PaymentProcessor do
  use GenServer
  require Logger
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  @impl true
  def init(_) do
    # 启动任务监督者
    {:ok, supervisor} = Task.Supervisor.start_link(name: MyApp.PaymentTaskSupervisor)
    {:ok, %{supervisor: supervisor}}
  end
  
  @doc """
  异步创建支付
  """
  def async_create_payment(params) do
    GenServer.cast(__MODULE__, {:create_payment, params})
  end
  
  @impl true
  def handle_cast({:create_payment, params}, %{supervisor: supervisor} = state) do
    # 启动异步任务处理支付
    Task.Supervisor.async_nolink(supervisor, fn ->
      try do
        case MyApp.WechatPayService.create_payment(params) do
          {:ok, result} ->
            # 处理成功结果
            handle_payment_success(params, result)
            
          {:error, reason} ->
            # 处理失败结果
            handle_payment_failure(params, reason)
        end
      rescue
        e ->
          Logger.error("处理支付请求异常: #{inspect(e)}")
          handle_payment_failure(params, :exception)
      end
    end)
    
    {:noreply, state}
  end
  
  defp handle_payment_success(params, result) do
    # 处理成功逻辑，如更新订单状态、发送通知等
    Logger.info("支付创建成功: #{inspect(result)}")
    # ...
  end
  
  defp handle_payment_failure(params, reason) do
    # 处理失败逻辑，如标记失败、发送通知等
    Logger.error("支付创建失败: #{inspect(reason)}")
    # ...
  end
end
```

## 自定义配置

SDK 允许通过自定义配置来满足不同的业务需求。

### 动态配置

在某些场景下，可能需要在运行时动态调整配置：

```elixir
# 更新超时配置
MyWechat.update_config(timeout: 10000)

# 切换到沙箱环境
MyWechat.update_config(service_host: "api.mch.weixin.qq.com/sandboxnew")

# 更新日志级别
MyWechat.update_config(log_level: :debug)
```

### 基于环境的配置

可以基于不同的环境（开发、测试、生产）使用不同的配置：

```elixir
# config/dev.exs
config :my_app, MyWechat,
  appid: "wx_dev_app_id",
  mchid: "dev_mch_id",
  service_host: "api.mch.weixin.qq.com/sandboxnew",  # 使用沙箱环境
  # 其他配置...
  log_level: :debug

# config/prod.exs
config :my_app, MyWechat,
  appid: "wx_prod_app_id",
  mchid: "prod_mch_id",
  service_host: "api.mch.weixin.qq.com",  # 使用生产环境
  # 其他配置...
  log_level: :info
```

### 覆盖初始化配置

可以通过覆盖 `init/1` 回调函数来自定义配置初始化逻辑：

```elixir
defmodule MyWechat do
  use ExWechatpay, otp_app: :my_app

  def init(config) do
    # 从环境变量中读取敏感配置
    config =
      config
      |> maybe_put_env(:appid, "WECHAT_PAY_APPID")
      |> maybe_put_env(:mchid, "WECHAT_PAY_MCHID")
      |> maybe_put_env(:apiv3_key, "WECHAT_PAY_APIV3_KEY")
      |> maybe_put_env(:client_key, "WECHAT_PAY_CLIENT_KEY")
    
    # 根据环境选择不同的服务主机
    config =
      if Application.get_env(:my_app, :env) == :prod do
        Keyword.put(config, :service_host, "api.mch.weixin.qq.com")
      else
        Keyword.put(config, :service_host, "api.mch.weixin.qq.com/sandboxnew")
      end
    
    {:ok, config}
  end
  
  # 辅助函数：如果环境变量存在，则使用环境变量的值
  defp maybe_put_env(config, key, env_var) do
    case System.get_env(env_var) do
      nil -> config
      value -> Keyword.put(config, key, value)
    end
  end
end
```

## 多商户支持

如果您的应用需要支持多个商户，可以创建多个微信支付客户端实例。

### 定义多个客户端模块

```elixir
defmodule MyApp.WechatPayA do
  use ExWechatpay, otp_app: :my_app
end

defmodule MyApp.WechatPayB do
  use ExWechatpay, otp_app: :my_app
end
```

### 配置多个客户端

```elixir
# config/config.exs
config :my_app, MyApp.WechatPayA,
  appid: "wx_app_id_a",
  mchid: "mch_id_a",
  # 其他配置...

config :my_app, MyApp.WechatPayB,
  appid: "wx_app_id_b",
  mchid: "mch_id_b",
  # 其他配置...
```

### 动态选择客户端

```elixir
defmodule MyApp.PaymentService do
  @doc """
  根据商户 ID 选择合适的微信支付客户端
  """
  def get_wechat_client(merchant_id) do
    case merchant_id do
      "merchant_a" -> MyApp.WechatPayA
      "merchant_b" -> MyApp.WechatPayB
      _ -> raise "未知的商户 ID: #{merchant_id}"
    end
  end
  
  @doc """
  创建支付订单
  """
  def create_payment(merchant_id, params) do
    client = get_wechat_client(merchant_id)
    client.create_native_transaction(params)
  end
  
  @doc """
  查询订单
  """
  def query_order(merchant_id, out_trade_no) do
    client = get_wechat_client(merchant_id)
    client.query_transaction_by_out_trade_no(out_trade_no)
  end
end
```

## 沙箱环境

微信支付提供了沙箱环境用于开发和测试。使用沙箱环境可以避免在开发过程中产生真实的交易。

### 配置沙箱环境

```elixir
# config/dev.exs
config :my_app, MyWechat,
  appid: "wx_sandbox_app_id",
  mchid: "sandbox_mch_id",
  service_host: "api.mch.weixin.qq.com/sandboxnew",  # 关键配置：使用沙箱主机
  # 其他配置与生产环境相同
```

### 沙箱环境测试

沙箱环境的使用方式与生产环境相同，但不会产生真实交易：

```elixir
# 创建沙箱测试订单
{:ok, result} = MyWechat.create_native_transaction(%{
  "description" => "沙箱测试商品",
  "out_trade_no" => "SANDBOX_ORDER_001",
  "amount" => %{
    "total" => 100,  # 1元
    "currency" => "CNY"
  }
})

# 使用沙箱环境的二维码进行测试支付
sandbox_code_url = result["code_url"]
```

## 完整支付流程示例

以下是一个完整的支付流程示例，从创建订单到处理支付结果：

### 1. 订单服务

```elixir
defmodule MyApp.OrderService do
  require Logger
  alias MyApp.Repo
  alias MyApp.Orders.Order
  
  @doc """
  创建订单并发起支付
  """
  def create_order_and_pay(user_id, product_id, quantity) do
    # 1. 创建订单记录
    with {:ok, product} <- get_product(product_id),
         {:ok, order} <- create_order(user_id, product, quantity),
         {:ok, payment_result} <- create_payment(order) do
      # 2. 返回支付信息
      {:ok, %{order: order, payment: payment_result}}
    end
  end
  
  # 获取商品信息
  defp get_product(product_id) do
    case Repo.get(MyApp.Products.Product, product_id) do
      nil -> {:error, :product_not_found}
      product -> {:ok, product}
    end
  end
  
  # 创建订单记录
  defp create_order(user_id, product, quantity) do
    # 计算订单金额
    amount = product.price * quantity
    
    # 生成唯一订单号
    out_trade_no = "ORDER_#{generate_order_id()}"
    
    # 创建订单记录
    %Order{}
    |> Order.changeset(%{
      user_id: user_id,
      product_id: product.id,
      quantity: quantity,
      amount: amount,
      out_trade_no: out_trade_no,
      status: "pending"
    })
    |> Repo.insert()
  end
  
  # 创建支付
  defp create_payment(order) do
    # 准备支付参数
    payment_params = %{
      "description" => "购买商品 #{order.product_id}",
      "out_trade_no" => order.out_trade_no,
      "amount" => %{
        "total" => trunc(order.amount * 100),  # 转换为分
        "currency" => "CNY"
      }
    }
    
    # 根据场景选择不同的支付方式
    case get_payment_scene() do
      :native ->
        # 扫码支付
        MyWechat.create_native_transaction(payment_params)
        
      :jsapi ->
        # JSAPI 支付（需要 openid）
        params_with_payer = Map.put(payment_params, "payer", %{
          "openid" => get_user_openid(order.user_id)
        })
        MyWechat.create_jsapi_transaction(params_with_payer)
        
      :h5 ->
        # H5 支付
        params_with_scene = Map.put(payment_params, "scene_info", %{
          "payer_client_ip" => get_client_ip(),
          "device_id" => get_device_id()
        })
        MyWechat.create_h5_transaction(params_with_scene)
    end
  end
  
  # 生成订单 ID
  defp generate_order_id do
    # 生成一个带时间戳的唯一 ID
    timestamp = :os.system_time(:millisecond)
    random = :rand.uniform(999999)
    "#{timestamp}#{random}"
  end
  
  # 获取支付场景（示例）
  defp get_payment_scene do
    # 根据实际业务逻辑决定使用哪种支付方式
    :native
  end
  
  # 获取用户 OpenID（示例）
  defp get_user_openid(user_id) do
    # 实际业务中，从数据库或缓存中获取用户的 OpenID
    "example_openid"
  end
  
  # 获取客户端 IP（示例）
  defp get_client_ip do
    # 实际业务中，从请求中获取客户端 IP
    "127.0.0.1"
  end
  
  # 获取设备 ID（示例）
  defp get_device_id do
    # 实际业务中，从请求中获取设备 ID
    "example_device_id"
  end
  
  @doc """
  处理支付结果
  """
  def handle_payment_result(payment_data) do
    # 从支付数据中提取关键信息
    out_trade_no = payment_data["out_trade_no"]
    transaction_id = payment_data["transaction_id"]
    trade_state = payment_data["trade_state"]
    
    # 查找订单
    with %Order{} = order <- Repo.get_by(Order, out_trade_no: out_trade_no) do
      # 更新订单状态
      new_status = case trade_state do
        "SUCCESS" -> "paid"
        "REFUND" -> "refunding"
        "NOTPAY" -> "pending"
        "CLOSED" -> "closed"
        "USERPAYING" -> "processing"
        "PAYERROR" -> "failed"
        _ -> "unknown"
      end
      
      # 更新订单记录
      order
      |> Order.changeset(%{
        status: new_status,
        transaction_id: transaction_id,
        payment_time: payment_data["success_time"]
      })
      |> Repo.update()
      
      # 如果支付成功，触发后续业务流程
      if new_status == "paid" do
        process_paid_order(order)
      end
    else
      nil ->
        Logger.error("找不到订单: #{out_trade_no}")
        {:error, :order_not_found}
    end
  end
  
  # 处理已支付订单的后续业务流程
  defp process_paid_order(order) do
    # 实际业务中，可能包括：
    # - 发送支付成功通知
    # - 更新库存
    # - 生成发货单
    # - 记录流水账
    Logger.info("处理已支付订单: #{order.id}")
    
    # 示例：发送支付成功通知
    MyApp.NotificationService.send_payment_success_notification(order)
  end
end
```

### 2. 支付控制器

```elixir
defmodule MyAppWeb.PaymentController do
  use MyAppWeb, :controller
  alias MyApp.OrderService
  
  @doc """
  创建支付
  """
  def create(conn, %{"product_id" => product_id, "quantity" => quantity}) do
    # 获取当前用户 ID
    user_id = conn.assigns.current_user.id
    
    case OrderService.create_order_and_pay(user_id, product_id, quantity) do
      {:ok, %{order: order, payment: payment_result}} ->
        # 根据支付方式返回不同的结果
        cond do
          Map.has_key?(payment_result, "code_url") ->
            # Native 支付，返回二维码链接
            render(conn, "native_payment.json", %{
              order_id: order.id,
              code_url: payment_result["code_url"]
            })
            
          Map.has_key?(payment_result, "prepay_id") ->
            # JSAPI 支付，生成支付参数
            pay_params = MyWechat.miniapp_payform(payment_result["prepay_id"])
            render(conn, "jsapi_payment.json", %{
              order_id: order.id,
              pay_params: pay_params
            })
            
          Map.has_key?(payment_result, "h5_url") ->
            # H5 支付，返回支付链接
            render(conn, "h5_payment.json", %{
              order_id: order.id,
              h5_url: payment_result["h5_url"]
            })
        end
        
      {:error, :product_not_found} ->
        conn
        |> put_status(:not_found)
        |> render("error.json", %{message: "商品不存在"})
        
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", %{changeset: changeset})
        
      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> render("error.json", %{message: "创建支付失败", error: error})
    end
  end
  
  @doc """
  查询支付状态
  """
  def query(conn, %{"order_id" => order_id}) do
    # 查询订单
    order = MyApp.Repo.get!(MyApp.Orders.Order, order_id)
    
    # 查询支付状态
    case MyWechat.query_transaction_by_out_trade_no(order.out_trade_no) do
      {:ok, payment_info} ->
        render(conn, "payment_status.json", %{
          order_id: order.id,
          status: payment_info["trade_state"],
          description: payment_info["trade_state_desc"]
        })
        
      {:error, _error} ->
        conn
        |> put_status(:internal_server_error)
        |> render("error.json", %{message: "查询支付状态失败"})
    end
  end
  
  @doc """
  关闭支付
  """
  def close(conn, %{"order_id" => order_id}) do
    # 查询订单
    order = MyApp.Repo.get!(MyApp.Orders.Order, order_id)
    
    # 关闭支付
    case MyWechat.close_transaction(order.out_trade_no) do
      :ok ->
        # 更新订单状态为已关闭
        MyApp.Orders.update_order_status(order, "closed")
        
        conn
        |> put_status(:ok)
        |> render("success.json", %{message: "支付已关闭"})
        
      {:error, _error} ->
        conn
        |> put_status(:internal_server_error)
        |> render("error.json", %{message: "关闭支付失败"})
    end
  end
end
```

### 3. 退款控制器

```elixir
defmodule MyAppWeb.RefundController do
  use MyAppWeb, :controller
  
  @doc """
  申请退款
  """
  def create(conn, %{"order_id" => order_id, "reason" => reason}) do
    # 查询订单
    order = MyApp.Repo.get!(MyApp.Orders.Order, order_id)
    
    # 生成退款单号
    out_refund_no = "REFUND_#{:os.system_time(:millisecond)}"
    
    # 申请退款
    refund_params = %{
      "out_refund_no" => out_refund_no,
      "out_trade_no" => order.out_trade_no,
      "reason" => reason,
      "amount" => %{
        "refund" => trunc(order.amount * 100),  # 全额退款，单位为分
        "total" => trunc(order.amount * 100),
        "currency" => "CNY"
      }
    }
    
    case MyWechat.create_refund(refund_params) do
      {:ok, refund_info} ->
        # 创建退款记录
        {:ok, refund} = MyApp.Refunds.create_refund(%{
          order_id: order.id,
          out_refund_no: out_refund_no,
          refund_id: refund_info["refund_id"],
          amount: order.amount,
          reason: reason,
          status: refund_info["status"]
        })
        
        # 更新订单状态
        MyApp.Orders.update_order_status(order, "refunding")
        
        render(conn, "refund.json", %{
          refund_id: refund.id,
          status: refund_info["status"]
        })
        
      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> render("error.json", %{message: "申请退款失败", error: error})
    end
  end
  
  @doc """
  查询退款
  """
  def show(conn, %{"id" => refund_id}) do
    # 查询退款记录
    refund = MyApp.Repo.get!(MyApp.Refunds.Refund, refund_id)
    
    # 查询退款状态
    case MyWechat.query_refund(refund.out_refund_no) do
      {:ok, refund_info} ->
        # 更新退款状态
        {:ok, updated_refund} = MyApp.Refunds.update_refund_status(refund, refund_info["status"])
        
        render(conn, "refund_status.json", %{
          refund: updated_refund,
          status: refund_info["status"],
          success_time: refund_info["success_time"]
        })
        
      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> render("error.json", %{message: "查询退款失败", error: error})
    end
  end
end
```

### 4. 前端集成示例

#### 微信小程序支付集成

```javascript
// 微信小程序支付
function requestPayment(payParams) {
  return new Promise((resolve, reject) => {
    wx.requestPayment({
      timeStamp: payParams.timeStamp,
      nonceStr: payParams.nonceStr,
      package: payParams.package,
      signType: payParams.signType,
      paySign: payParams.paySign,
      success: function(res) {
        resolve(res);
      },
      fail: function(err) {
        reject(err);
      }
    });
  });
}

// 调用支付接口
async function createOrder(productId, quantity) {
  try {
    // 调用创建订单接口
    const response = await fetch('/api/payments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        product_id: productId,
        quantity: quantity
      })
    });
    
    const result = await response.json();
    
    if (result.pay_params) {
      // JSAPI 支付，直接调起支付
      await requestPayment(result.pay_params);
      return { success: true, orderId: result.order_id };
    } else {
      throw new Error('不支持的支付方式');
    }
  } catch (error) {
    console.error('支付失败', error);
    return { success: false, error: error.message };
  }
}
```

#### Web 端扫码支付集成

```javascript
// Web 端扫码支付
async function createQRCodePayment(productId, quantity) {
  try {
    // 调用创建订单接口
    const response = await fetch('/api/payments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        product_id: productId,
        quantity: quantity
      })
    });
    
    const result = await response.json();
    
    if (result.code_url) {
      // 生成二维码
      generateQRCode(result.code_url, 'qrcode-container');
      
      // 开始轮询订单状态
      startPollingOrderStatus(result.order_id);
      
      return { success: true, orderId: result.order_id };
    } else {
      throw new Error('不支持的支付方式');
    }
  } catch (error) {
    console.error('创建支付失败', error);
    return { success: false, error: error.message };
  }
}

// 生成二维码
function generateQRCode(codeUrl, containerId) {
  // 使用 qrcode.js 库生成二维码
  new QRCode(document.getElementById(containerId), {
    text: codeUrl,
    width: 256,
    height: 256
  });
}

// 轮询订单状态
function startPollingOrderStatus(orderId) {
  const intervalId = setInterval(async () => {
    try {
      const response = await fetch(`/api/payments/${orderId}/status`);
      const result = await response.json();
      
      // 显示支付状态
      updatePaymentStatus(result.status, result.description);
      
      // 如果支付成功或已关闭，停止轮询
      if (['SUCCESS', 'CLOSED', 'PAYERROR'].includes(result.status)) {
        clearInterval(intervalId);
        
        if (result.status === 'SUCCESS') {
          // 支付成功，跳转到成功页面
          window.location.href = `/orders/${orderId}/success`;
        }
      }
    } catch (error) {
      console.error('查询支付状态失败', error);
    }
  }, 3000); // 每 3 秒查询一次
  
  // 5 分钟后自动停止轮询
  setTimeout(() => {
    clearInterval(intervalId);
  }, 5 * 60 * 1000);
}

// 更新支付状态显示
function updatePaymentStatus(status, description) {
  const statusElement = document.getElementById('payment-status');
  statusElement.textContent = description || status;
  
  // 根据状态设置不同样式
  statusElement.className = `payment-status payment-status-${status.toLowerCase()}`;
}
```

#### H5 支付集成

```javascript
// H5 支付
async function createH5Payment(productId, quantity) {
  try {
    // 调用创建订单接口
    const response = await fetch('/api/payments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        product_id: productId,
        quantity: quantity
      })
    });
    
    const result = await response.json();
    
    if (result.h5_url) {
      // 记录订单 ID，用于支付完成后查询
      localStorage.setItem('current_order_id', result.order_id);
      
      // 跳转到微信支付页面
      window.location.href = result.h5_url;
      
      return { success: true, orderId: result.order_id };
    } else {
      throw new Error('不支持的支付方式');
    }
  } catch (error) {
    console.error('创建支付失败', error);
    return { success: false, error: error.message };
  }
}

// H5 支付完成后的回调处理
function handleH5PaymentReturn() {
  // 从本地存储获取订单 ID
  const orderId = localStorage.getItem('current_order_id');
  
  if (orderId) {
    // 查询订单状态
    fetch(`/api/payments/${orderId}/status`)
      .then(response => response.json())
      .then(result => {
        // 显示支付结果
        if (result.status === 'SUCCESS') {
          showPaymentSuccess();
        } else {
          showPaymentFailed(result.description);
        }
      })
      .catch(error => {
        console.error('查询支付状态失败', error);
        showPaymentFailed('查询支付状态失败');
      })
      .finally(() => {
        // 清除本地存储的订单 ID
        localStorage.removeItem('current_order_id');
      });
  }
}

// 页面加载时检查是否是支付回调
document.addEventListener('DOMContentLoaded', function() {
  // 检查 URL 参数或其他标记，判断是否是从微信支付页面返回
  const isPaymentReturn = new URLSearchParams(window.location.search).has('payment_return');
  
  if (isPaymentReturn) {
    handleH5PaymentReturn();
  }
});
```

以上示例展示了一个完整的微信支付集成流程，包括创建支付、查询状态、处理回调和前端集成。实际项目中，可能需要根据具体业务需求进行调整和优化。