defmodule HelloElixir.Database do
  @moduledoc false

  @timeout 1_000

  def ready? do
    case Application.get_env(:hello_elixir, :database_url) do
      nil -> :ok
      "" -> :ok
      database_url -> check_tcp(database_url)
    end
  end

  defp check_tcp(database_url) do
    with %URI{host: host, port: port} when is_binary(host) and is_integer(port) <-
           URI.parse(database_url),
         {:ok, address} <- :inet.getaddr(String.to_charlist(host), :inet),
         {:ok, socket} <- :gen_tcp.connect(address, port, [:binary, active: false], @timeout) do
      :gen_tcp.close(socket)
      :ok
    else
      _ -> {:error, :database_unreachable}
    end
  end
end
