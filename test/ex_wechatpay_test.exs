defmodule ExWechatpayTest do
  use ExUnit.Case

  alias ExWechatpay.Test.App

  setup do
    test_cert_path = System.get_env("HOPE_WECHAT_CERT_PATH")

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

  test "get_certificates" do
    assert {:ok, res} = App.get_certificates()
    ExWechatpay.Debug.debug(res)
  end
end
