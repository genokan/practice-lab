defmodule HelloElixir.DatabaseTest do
  use ExUnit.Case, async: true

  test "readiness succeeds when a database has not been configured" do
    previous = Application.get_env(:hello_elixir, :database_url)
    Application.delete_env(:hello_elixir, :database_url)

    assert :ok = HelloElixir.Database.ready?()

    if previous, do: Application.put_env(:hello_elixir, :database_url, previous)
  end
end
