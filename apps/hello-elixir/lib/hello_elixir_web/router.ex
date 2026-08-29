defmodule HelloElixirWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/" do
    pipe_through(:api)

    get("/", HelloElixirWeb.StatusController, :show)
    get("/health/live", HelloElixirWeb.HealthController, :live)
    get("/health/ready", HelloElixirWeb.HealthController, :ready)
    get("/metrics", HelloElixirWeb.MetricsController, :show)
  end
end
