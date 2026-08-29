import Config

port = System.get_env("PORT", "4000") |> String.to_integer()

config :hello_elixir,
  port: port,
  app_environment: System.get_env("APP_ENV", "development"),
  app_version: System.get_env("APP_VERSION", "dev"),
  database_url: System.get_env("DATABASE_URL")
