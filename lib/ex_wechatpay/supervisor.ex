defmodule ExWechatpay.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(name, config) do
    Supervisor.start_link(__MODULE__, {name, config}, name: supervisor_name(name))
  end

  @doc false
  @impl Supervisor
  def init({name, config}) do
    children =
      [
        {Finch, name: finch_name(name)},
        {ExWechatpay.Config.Manager, {name, config, []}},
        {ExWechatpay.Core, {name, %ExWechatpay.Http.Finch{finch_name: finch_name(name)}, config}}
      ] ++ virtual_pay_children(name, config)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp virtual_pay_children(name, config) do
    if config[:virtual_pay] do
      [{ExWechatpay.VirtualPay.TokenAgent, [name: token_agent_name(name)]}]
    else
      []
    end
  end

  defp token_agent_name(name) do
    Module.concat(name, VirtualPayTokenAgent)
  end

  defp supervisor_name(name) do
    Module.concat(name, Supervisor)
  end

  defp finch_name(name) do
    Module.concat(name, Finch)
  end
end
