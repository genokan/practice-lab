import Config

config :hello_elixir, port: 4000

config :logger, :console, format: "$time $metadata[$level] $message\n", metadata: [:request_id]

import_config "#{config_env()}.exs"
