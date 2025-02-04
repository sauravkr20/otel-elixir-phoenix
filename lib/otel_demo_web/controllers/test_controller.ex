defmodule OtelDemoWeb.TestController do
  use OtelDemoWeb, :controller
  alias OtelDemoWeb.Tracer

  def index(conn, _params) do
    ctx = conn.assigns.otel_ctx

    # Create nested spans
    ctx = Tracer.start_span("test_action", ctx)
    ctx = Tracer.add_event("processing_started", ctx)

    ctx = perform_operation(ctx)

    ctx = Tracer.end_span(ctx)
    text(conn, "OK")
  end

  defp perform_operation(ctx) do
    ctx = Tracer.start_span("database_operation", ctx)
    :timer.sleep(100)
    Tracer.add_event("query_executed", ctx, %{query: "SELECT * FROM users"})
    Tracer.end_span(ctx)
  end
end
