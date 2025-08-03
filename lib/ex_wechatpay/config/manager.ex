defmodule ExWechatpay.Config.Manager do
  @moduledoc """
  配置管理器模块

  该模块负责管理 ExWechatpay 的配置，提供配置热更新功能。
  通过使用 Agent 进程保存配置，可以在运行时动态更新配置。
  """

  use GenServer

  alias ExWechatpay.Config.Provider

  # 1 day
  @default_interval 60_000 * 60 * 24

  @doc """
  启动配置管理器

  ## 参数
    * `name` - 配置管理器名称
    * `config` - 初始配置
    * `opts` - 额外选项
      * `:auto_update` - 是否启用自动更新证书（默认：false）
      * `:update_interval` - 自动更新间隔（毫秒，默认：1天）

  ## 返回值
    * `{:ok, pid}` - 成功启动的 GenServer 进程 ID
    * `{:error, reason}` - 启动失败的原因
  """
  @spec start_link({atom(), keyword(), keyword()}) :: GenServer.on_start()
  def start_link({name, config, opts}) do
    GenServer.start_link(__MODULE__, {name, config, opts}, name: manager_name(name))
  end

  @doc """
  获取当前配置

  ## 参数
    * `name` - 配置管理器名称

  ## 返回值
    * `config` - 当前配置
  """
  @spec get_config(atom()) :: keyword()
  def get_config(name) do
    Provider.get_current_config(name)
  end

  @doc false
  defp manager_name(name) do
    Module.concat(name, ConfigManager)
  end

  @doc """
  更新配置

  ## 参数
    * `name` - 配置管理器名称
    * `updates` - 要更新的配置

  ## 返回值
    * `{:ok, new_config}` - 更新后的配置
    * `{:error, error}` - 更新失败的错误信息
  """
  @spec update_config(atom(), keyword()) :: {:ok, keyword()} | {:error, term()}
  def update_config(name, updates) do
    GenServer.call(manager_name(name), {:update_config, updates})
  end

  @doc """
  更新证书

  从微信支付服务器获取最新的平台证书并更新配置。

  ## 参数
    * `name` - 配置管理器名称
    * `client_name` - 客户端名称（用于调用 API）

  ## 返回值
    * `{:ok, new_config}` - 更新后的配置
    * `{:error, error}` - 更新失败的错误信息
  """
  @spec update_certificates(atom(), atom()) :: {:ok, keyword()} | {:error, term()}
  def update_certificates(name, client_name) do
    GenServer.call(manager_name(name), {:update_certificates, client_name})
  end

  @doc """
  启用自动更新证书

  ## 参数
    * `name` - 配置管理器名称
    * `client_name` - 客户端名称（用于调用 API）
    * `interval` - 更新间隔（毫秒，默认：1天）

  ## 返回值
    * `:ok` - 成功启用
  """
  @spec enable_auto_update(atom(), atom(), non_neg_integer()) :: :ok
  def enable_auto_update(name, client_name, interval \\ @default_interval) do
    GenServer.cast(manager_name(name), {:enable_auto_update, client_name, interval})
  end

  @doc """
  禁用自动更新证书

  ## 参数
    * `name` - 配置管理器名称

  ## 返回值
    * `:ok` - 成功禁用
  """
  @spec disable_auto_update(atom()) :: :ok
  def disable_auto_update(name) do
    GenServer.cast(manager_name(name), :disable_auto_update)
  end

  # GenServer 回调函数

  @impl GenServer
  def init({name, _config, opts}) do
    auto_update = Keyword.get(opts, :auto_update, false)
    update_interval = Keyword.get(opts, :update_interval, @default_interval)
    client_name = name

    state = %{
      name: name,
      client_name: client_name,
      auto_update: auto_update,
      update_interval: update_interval,
      timer_ref: nil
    }

    if auto_update do
      {:ok, schedule_update(state)}
    else
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_call({:update_config, updates}, _from, state) do
    case Provider.update_config(state.name, updates) do
      {:ok, new_config} ->
        {:reply, {:ok, new_config}, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl GenServer
  def handle_call({:update_certificates, client_name}, _from, state) do
    result = do_update_certificates(state.name, client_name)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_cast({:enable_auto_update, client_name, interval}, state) do
    # 取消现有的定时器（如果有）
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    new_state =
      state
      |> Map.put(:auto_update, true)
      |> Map.put(:client_name, client_name)
      |> Map.put(:update_interval, interval)
      |> schedule_update()

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(:disable_auto_update, state) do
    # 取消定时器
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    new_state =
      state
      |> Map.put(:auto_update, false)
      |> Map.put(:timer_ref, nil)

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:update_certificates, state) do
    if state.auto_update do
      # 尝试更新证书
      _ = do_update_certificates(state.name, state.client_name)
      # 无论成功与否，都重新调度下一次更新
      {:noreply, schedule_update(state)}
    else
      {:noreply, state}
    end
  end

  # 私有辅助函数

  defp schedule_update(state) do
    timer_ref = Process.send_after(self(), :update_certificates, state.update_interval)
    %{state | timer_ref: timer_ref}
  end

  defp do_update_certificates(name, client_name) do
    # 获取当前配置
    _current_config = Provider.get_current_config(name)

    # 调用 API 获取新的证书
    case apply(client_name, :get_certificates, []) do
      {:ok, %{"data" => certificates}} ->
        # 转换证书格式
        wx_pubs =
          Enum.map(certificates, fn %{"serial_no" => serial_no, "certificate" => cert} ->
            {serial_no, cert}
          end)

        # 更新配置
        Provider.update_config(name, wx_pubs: wx_pubs)

      error ->
        error
    end
  end
end
