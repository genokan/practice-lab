defmodule HelloElixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :hello_elixir,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [hello_elixir: [include_executables_for: [:unix]]]
    ]
  end

  def application do
    [
      mod: {HelloElixir.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.12.5"},
      {:jason, "~> 1.4"},
      {:phoenix, "~> 1.8.13"}
    ]
  end
end
