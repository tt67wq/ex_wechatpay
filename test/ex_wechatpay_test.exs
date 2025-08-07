defmodule ExWechatpayTest do
  use ExUnit.Case

  alias ExWechatpay.Test.App
  alias ExWechatpay.Util

  setup do
    test_cert_path = System.get_env("TEST_WECHAT_CERT_PATH")

    cfg = [
      appid: "wxefd6b215fca0cacd",
      mchid: "1611120167",
      notify_url: "https://test.domain/api/notify/wechat_pay",
      apiv3_key: "A212399AjklasMDKNmA1232D91281230",
      wx_pubs: [
        {"35CE31ED8F4A50B930FF8D37C51B5ADA03265E72", File.read!(Path.join(test_cert_path, "wx_pub.pem"))}
      ],
      client_serial_no: "1C995B73884734F30327FD63C46DA5386C086104",
      client_key: File.read!(Path.join(test_cert_path, "apiclient_key.pem")),
      client_cert: File.read!(Path.join(test_cert_path, "apiclient_cert.pem"))
    ]

    Application.put_env(:my_test, ExWechatpay.Test.App, cfg)

    start_supervised!(ExWechatpay.Test.App)

    :ok
  end

  # @tag exec: true
  test "get_certificates" do
    assert {:ok, res} = App.get_certificates()
    ExWechatpay.Debug.debug(res)
  end

  test "create_native_transaction" do
    assert {:ok, res} =
             App.create_native_transaction(%{
               :description => "Image形象店-深圳腾大-QQ公仔",
               :out_trade_no => Util.random_string(12),
               :notify_url => "https://www.weixin.qq.com/wxpay/pay.php",
               :amount => %{
                 :total => 1,
                 :currency => "CNY"
               }
             })

    ExWechatpay.Debug.debug(res)
  end

  # @tag exec: true
  test "create_jsapi_transaction" do
    assert {:ok, res} =
             App.create_jsapi_transaction(%{
               :description => "Image形象店-深圳腾大-QQ公仔",
               :out_trade_no => Util.random_string(12),
               :notify_url => "https://www.weixin.qq.com/wxpay/pay.php",
               :amount => %{
                 :total => 1,
                 :currency => "CNY"
               },
               :payer => %{
                 :openid => "ohNY75Bxh362oNB0Zu5aF_-hAHP4"
               }
             })

    ExWechatpay.Debug.debug(res)
  end

  # @tag exec: true
  test "query_transaction_by_out_trade_no" do
    assert {:ok, res} = App.query_transaction_by_out_trade_no("1217752501201407033233368018")
    ExWechatpay.Debug.debug(res)
  end

  # @tag exec: true
  test "query_transaction_by_transaction_id" do
    assert {:ok, res} = App.query_transaction_by_transaction_id("4200001851202305317391703081")
    ExWechatpay.Debug.debug(res)
  end

  @tag exec: true
  test "close_transaction" do
    out_trade_no = Util.random_string(12)

    App.create_native_transaction(%{
      :description => "Image形象店-深圳腾大-QQ公仔",
      :out_trade_no => out_trade_no,
      :out_trade_no => out_trade_no,
      :notify_url => "https://www.weixin.qq.com/wxpay/pay.php",
      :amount => %{
        :total => 1,
        :currency => "CNY"
      }
    })

    assert :ok == App.close_transaction(out_trade_no)
  end
end
