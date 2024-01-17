defmodule ExWechatpay.Util do
  @moduledoc false

  @spec timestamp(atom()) :: integer()
  def timestamp(typ \\ :seconds), do: :os.system_time(typ)

  @doc """
  generate random string
  ## Example

  iex(17)> Common.Crypto.random_string 16
  "2jqDlUxDuOt-qyyZ"
  """
  @spec random_string(integer()) :: String.t()
  def random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  @doc """
  decode pem
  ## Examples

  iex> a = "-----BEGIN CERTIFICATE-----.....-----END CERTIFICATE-----"
  iex> ExWechatpay.Util.load_pem(a)
  {:Certificate,
   {:TBSCertificate, :v3, 307174813703957890295931636658482501901655367282,
    {:AlgorithmIdentifier, {1, 2, 840, 113549, 1, 1, 11}, <<5, 0>>},
    {:rdnSequence,
     [
       [{:AttributeTypeAndValue, {2, 5, 4, 6}, <<19, 2, 67, 78>>}],
       [
         {:AttributeTypeAndValue, {2, 5, 4, 10},
          <<19, 10, 84, 101, 110, 112, 97, 121, 46, 99, 111, 109>>}
       ],
       [
         {:AttributeTypeAndValue, {2, 5, 4, 11},
          <<19, 20, 84, 101, 110, 112, 97, 121, 46, 99, 111, 109, 32, 67, 65, 32,
            67, 101, 110, 116, 101, 114>>}
       ],
       [
         {:AttributeTypeAndValue, {2, 5, 4, 3},
          <<19, 18, 84, 101, 110, 112, 97, 121, 46, 99, 111, 109, 32, 82, 111,
            111, 116, 32, 67, 65>>}
       ]
     ]}, {:Validity, {:utcTime, '210623060922Z'}, {:utcTime, '260622060922Z'}},
    {:rdnSequence,
     [
       [
         {:AttributeTypeAndValue, {2, 5, 4, 3},
          <<12, 15, 84, 101, 110, 112, 97, 121, 46, 99, 111, 109, 32, 115, 105,
            103, 110>>}
       ],
       [{:AttributeTypeAndValue, {2, 5, 4, 10}, "\f\nTenpay.com"}],
       [
         {:AttributeTypeAndValue, {2, 5, 4, 11},
          <<12, 20, 84, 101, 110, 112, 97, 121, 46, 99, 111, 109, 32, 67, 65, 32,
            67, 101, 110, 116, 101, 114>>}
       ],
       [{:AttributeTypeAndValue, {2, 5, 4, 6}, <<12, 2, 67, 78>>}],
       [{:AttributeTypeAndValue, {2, 5, 4, 7}, "\f\bShenZhen"}]
     ]},
    {:SubjectPublicKeyInfo,
     {:AlgorithmIdentifier, {1, 2, 840, 113549, 1, 1, 1}, <<5, 0>>},
     <<48, 130, 1, 10, 2, 130, 1, 1, 0, 202, 100, 223, 159, 99, 152, 111, 136,
       228, 139, 86, 207, 103, 239, 200, 180, 181, 17, 231, 165, 109, 202, 27,
       206, 128, 65, 126, 246, ...>>}, :asn1_NOVALUE, :asn1_NOVALUE,
    [
      {:Extension, {2, 5, 29, 19}, false, <<48, 0>>},
      {:Extension, {2, 5, 29, 15}, false, <<3, 2, 4, 240>>},
      {:Extension, {2, 5, 29, 31}, false,
       <<48, 92, 48, 90, 160, 88, 160, 86, 134, 84, 104, 116, 116, 112, 58, 47,
         47, 101, 118, 99, 97, 46, 105, 116, 114, 117, 115, 46, 99, 111, ...>>}
    ]}, {:AlgorithmIdentifier, {1, 2, 840, 113549, 1, 1, 11}, <<5, 0>>},
   <<153, 152, 68, 3, 48, 179, 28, 112, 77, 59, 203, 196, 226, 35, 170, 13, 17,
     246, 196, 139, 249, 247, 234, 182, 66, 207, 177, 67, 59, 143, 107, 146, 11,
     40, 10, 82, 103, 0, 224, 221, 16, 73, 74, 127, 177, 43, ...>>}
  """
  @spec load_pem(binary) :: term()
  def load_pem(pem) do
    pem
    |> :public_key.pem_decode()
    |> List.first()
    |> :public_key.pem_entry_decode()
  end
end
