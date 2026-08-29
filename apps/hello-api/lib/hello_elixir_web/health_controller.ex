defmodule HelloElixirWeb.HealthController do
  use Phoenix.Controller, formats: [:json]

  def live(conn, _params), do: json(conn, %{status: "ok"})

  def ready(conn, _params) do
    case HelloElixir.Database.ready?() do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :database_unreachable} ->
        conn |> put_status(:service_unavailable) |> json(%{status: "unavailable"})
    end
  end
end
