defmodule ExWechatpay.VirtualPay.CallbackTest do
  use ExUnit.Case, async: true

  alias ExWechatpay.VirtualPay.Callback

  describe "parse_deliver/1" do
    test "parses JSON body with PascalCase fields" do
      body =
        Jason.encode!(%{
          "OpenId" => "openid_xxx",
          "OutTradeNo" => "VP123",
          "GoodsInfo" => %{"ProductId" => "vip_six_week"}
        })

      assert {:ok, result} = Callback.parse_deliver(body)
      assert result.openid == "openid_xxx"
      assert result.out_trade_no == "VP123"
      assert result.product_id == "vip_six_week"
    end

    test "parses JSON body with snake_case fields" do
      body =
        Jason.encode!(%{
          "openid" => "openid_yyy",
          "out_trade_no" => "VP456",
          "goods_info" => %{"product_id" => "vip_one_year"}
        })

      assert {:ok, result} = Callback.parse_deliver(body)
      assert result.openid == "openid_yyy"
      assert result.out_trade_no == "VP456"
      assert result.product_id == "vip_one_year"
    end

    test "accepts pre-parsed map" do
      params = %{
        "OpenId" => "openid_zzz",
        "OutTradeNo" => "VP789",
        "GoodsInfo" => %{"ProductId" => "vip_eternal"}
      }

      assert {:ok, result} = Callback.parse_deliver(params)
      assert result.openid == "openid_zzz"
      assert result.out_trade_no == "VP789"
      assert result.product_id == "vip_eternal"
    end

    test "returns error for missing required fields" do
      body = Jason.encode!(%{"SomeField" => "value"})
      assert {:error, _} = Callback.parse_deliver(body)
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Callback.parse_deliver("not json")
    end

    test "handles missing GoodsInfo gracefully" do
      body = Jason.encode!(%{"OpenId" => "xxx", "OutTradeNo" => "VP001"})
      assert {:ok, result} = Callback.parse_deliver(body)
      assert result.product_id == nil
    end
  end

  describe "parse_refund/1" do
    test "parses refund callback with PascalCase" do
      body =
        Jason.encode!(%{
          "OpenId" => "openid_aaa",
          "WxRefundId" => "refund_001",
          "RefundFee" => 3000,
          "RetCode" => 0
        })

      assert {:ok, result} = Callback.parse_refund(body)
      assert result.openid == "openid_aaa"
      assert result.wx_refund_id == "refund_001"
      assert result.refund_fee == 3000
      assert result.ret_code == 0
    end

    test "parses refund callback with snake_case" do
      body =
        Jason.encode!(%{
          "openid" => "openid_bbb",
          "wx_refund_id" => "refund_002",
          "refund_fee" => 1000,
          "ret_code" => 0
        })

      assert {:ok, result} = Callback.parse_refund(body)
      assert result.openid == "openid_bbb"
      assert result.wx_refund_id == "refund_002"
    end

    test "returns error for missing required fields" do
      body = Jason.encode!(%{"RefundFee" => 100})
      assert {:error, _} = Callback.parse_refund(body)
    end
  end

  describe "success_response/0" do
    test "returns correct format" do
      assert Callback.success_response() == %{"ErrCode" => 0, "ErrMsg" => "success"}
    end
  end
end
