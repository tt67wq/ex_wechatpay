defmodule ExWechatpay.Test.App do
  @moduledoc false

  use ExWechatpay, otp_app: :my_test

  def init(config) do
    ExWechatpay.Model.ConfigOption.validate(config)
  end
end
