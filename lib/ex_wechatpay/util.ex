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
  {:ok, {:Certificate, ...}}  # 成功时返回 {:ok, parsed_certificate}
  {:error, reason}           # 失败时返回 {:error, reason}
  """
  @spec load_pem(binary) :: {:ok, term()} | {:error, term()}
  def load_pem(pem) do
    case :public_key.pem_decode(pem) do
      [] ->
        {:error, :no_valid_entries}

      [entry | _] ->
        try_pem_entry_decode(entry)
    end
  end

  # 尝试使用标准方法解析 PEM 条目
  defp try_pem_entry_decode(entry) do
    case :public_key.pem_entry_decode(entry) do
      {:error, _reason} ->
        # 标准方法失败，尝试备用方法
        try_alternative_decode(entry)

      result ->
        {:ok, result}
    end
  rescue
    _error ->
      # 处理解码异常，尝试备用方法
      try_alternative_decode(entry)
  end

  # 备用解码方法，使用 OTPCertificate 类型
  defp try_alternative_decode({:Certificate, der, :not_encrypted}) do
    result = :public_key.der_decode(:OTPCertificate, der)
    {:ok, result}
  rescue
    error ->
      {:error, {:decode_failed, error}}
  end

  defp try_alternative_decode(_entry) do
    {:error, :unsupported_entry_type}
  end
end
