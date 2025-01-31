defmodule OtelDemo.Repo do
  use Ecto.Repo,
    otp_app: :otel_demo,
    adapter: Ecto.Adapters.Postgres
end
