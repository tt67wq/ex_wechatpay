defmodule ExWechatpay.VirtualPay.SignatureTest do
  use ExUnit.Case, async: true

  alias ExWechatpay.VirtualPay.Signature

  describe "pay_sig/3" do
    test "produces correct HMAC-SHA256 hex lowercase" do
      result = Signature.pay_sig("my_key", "/xpay/query_user_balance", ~s({"openid":"test"}))

      expected =
        :hmac
        |> :crypto.mac(:sha256, "my_key", "/xpay/query_user_balance&" <> ~s({"openid":"test"}))
        |> Base.encode16(case: :lower)

      assert result == expected
    end

    test "known vector" do
      # Verify against a known output
      result = Signature.pay_sig("key", "/xpay/test", "body")

      assert result ==
               :hmac
               |> :crypto.mac(:sha256, "key", "/xpay/test&body")
               |> Base.encode16(case: :lower)

      # Ensure it's 64 hex chars (256 bits)
      assert String.length(result) == 64
      assert result =~ ~r/^[0-9a-f]{64}$/
    end
  end

  describe "client_pay_sig/2" do
    test "includes requestVirtualPayment& prefix" do
      sign_data_str = ~s({"offerId":"123"})

      result = Signature.client_pay_sig("key", sign_data_str)

      expected =
        :hmac
        |> :crypto.mac(:sha256, "key", "requestVirtualPayment&" <> sign_data_str)
        |> Base.encode16(case: :lower)

      assert result == expected
    end

    test "differs from pay_sig for same input" do
      data = "test_data"
      key = "key"

      pay = Signature.pay_sig(key, "", data)
      client = Signature.client_pay_sig(key, data)

      # pay_sig uses "" + "&" + data, client uses "requestVirtualPayment&" + data
      assert pay != client
    end
  end

  describe "user_signature/2" do
    test "uses session_key as HMAC key" do
      result = Signature.user_signature("session_123", ~s({"offerId":"456"}))

      expected =
        :hmac
        |> :crypto.mac(:sha256, "session_123", ~s({"offerId":"456"}))
        |> Base.encode16(case: :lower)

      assert result == expected
    end
  end
end
