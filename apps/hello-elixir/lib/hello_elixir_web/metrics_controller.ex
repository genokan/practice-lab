defmodule HelloElixirWeb.MetricsController do
  import Plug.Conn

  def show(conn, _params) do
    environment = Application.fetch_env!(:hello_elixir, :app_environment)
    version = Application.fetch_env!(:hello_elixir, :app_version)

    body = """
    # HELP hello_elixir_up Whether the application is available.
    # TYPE hello_elixir_up gauge
    hello_elixir_up 1
    # HELP hello_elixir_info Immutable application metadata.
    # TYPE hello_elixir_info gauge
    hello_elixir_info{environment=\"#{environment}\",version=\"#{version}\"} 1
    """

    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, body)
  end
end
