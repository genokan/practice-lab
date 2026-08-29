defmodule HelloElixir.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Bandit, plug: HelloElixirWeb.Router, scheme: :http, port: app_port()}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: HelloElixir.Supervisor)
  end

  defp app_port, do: Application.fetch_env!(:hello_elixir, :port)
end
