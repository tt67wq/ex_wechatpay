defmodule ExWechatpayTest do
  use ExUnit.Case

  alias ExWechatpay.Util

  setup_all do
    test_data = File.read!("tmp/test.json") |> Jason.decode!()
    # {
    #     "appid": "wxefd6b2150cac",
    #     "mchid": "1611167",
    #     "notify_url": "https://www.example.com",
    #     "apiv3_key": "A21AjklasMDKNmA1232D91281230",
    #     "client_serial_no": "1C984734F30327FD63C46DA5386C086104",
    #     "client_key": "-----BEGIN PRIVATE KEY-----.....-----END PRIVATE KEY-----\n",
    #     "client_cert": "-----BEGIN CERTIFICATE-----.....-----END CERTIFICATE-----\n",
    #     "wx_pubs": [
    #         {
    #             "wechatpay-serial": "35CE31ED8F4A5037C51B5ADA03265E72",
    #             "public_key": "-----BEGIN PUBLIC KEY-----.....-----END PUBLIC KEY-----\n"
    #         }
    #     ]
    # }

    client =
      ExWechatpay.Client.new(
        appid: test_data["appid"],
        mchid: test_data["mchid"],
        notify_url: test_data["notify_url"],
        apiv3_key: test_data["apiv3_key"],
        client_serial_no: test_data["client_serial_no"],
        client_key: test_data["client_key"],
        client_cert: test_data["client_cert"],
        wx_pubs:
          test_data["wx_pubs"] |> Enum.map(fn x -> {x["wechatpay-serial"], x["public_key"]} end),
        http_client: ExWechatpay.Http.Default.new()
      )

    wechat = ExWechatpay.new(client: client)
    start_supervised!({ExWechatpay, wechat: wechat})
    [wechat: wechat]
  end

  test "get_certificates", %{wechat: wechat} do
    assert {:ok, _} = ExWechatpay.get_certificates(wechat)
  end

  test "create_native_transaction", %{wechat: wechat} do
    assert {:ok, _} =
             ExWechatpay.create_native_transaction(wechat, %{
               "out_trade_no" => "test_#{Util.random_string(10)}",
               "amount" => %{"total" => 1},
               "description" => "test"
             })
  end

  test "create_jsapi_transaction", %{wechat: wechat} do
    assert {:ok, _} =
             ExWechatpay.create_jsapi_transaction(wechat, %{
               "out_trade_no" => "test_#{Util.random_string(10)}",
               "amount" => %{"total" => 1},
               "description" => "test",
               "payer" => %{
                 "openid" => "ohNY75NwfDWPKfbaQfpF0KDVfXFQ"
               }
             })
  end

  test "create_h5_transaction", %{wechat: wechat} do
    assert {:ok, _} =
             ExWechatpay.create_h5_transaction(wechat, %{
               "out_trade_no" => "test_#{Util.random_string(10)}",
               "amount" => %{"total" => 1},
               "description" => "test",
               "scene_info" => %{
                 "payer_client_ip" => "127.0.0.1"
               }
             })
  end

  test "query_transaction_by_out_trade_no", %{wechat: wechat} do
    assert {:ok, _} = ExWechatpay.query_transaction(wechat, :out_trade_no, "testO_1234567890")
  end

  test "query_transaction_by_transaction_id", %{wechat: wechat} do
    assert {:ok, _} =
             ExWechatpay.query_transaction(
               wechat,
               :transaction_id,
               "4200001851202305317391703081"
             )
  end

  test "miniapp_payform", %{wechat: wechat} do
    assert {:ok, _} = ExWechatpay.miniapp_payform(wechat, "testO_1234567890")
  end

  test "create refund", %{wechat: wechat} do
    assert {:ok, _} =
             ExWechatpay.create_refund(wechat, %{
               "out_trade_no" => "test_QQuuheTjp7",
               "out_refund_no" => "refund_#{Util.random_string(10)}",
               "amount" => %{
                 "refund" => 1,
                 "total" => 1,
                 "currency" => "CNY"
               }
             })
  end

  test "close_transaction", %{wechat: wechat} do
    out_trade_no = "test_#{Util.random_string(10)}"

    ExWechatpay.create_native_transaction(wechat, %{
      "out_trade_no" => out_trade_no,
      "amount" => %{"total" => 1},
      "description" => "test"
    })

    assert :ok = ExWechatpay.close_transaction(wechat, out_trade_no)
  end
end
