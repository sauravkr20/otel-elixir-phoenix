defmodule OtelDemo.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Initialize OpenTelemetry integrations
    :ok = OpentelemetryPhoenix.setup()

    children = [
      OtelDemoWeb.Telemetry,
      OtelDemo.Repo,
      {DNSCluster, query: Application.get_env(:otel_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OtelDemo.PubSub},
      OtelDemoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: OtelDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    OtelDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
