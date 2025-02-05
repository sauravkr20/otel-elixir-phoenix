defmodule OtelDemoWeb.TestController do
  use OtelDemoWeb, :controller
  alias OtelDemoWeb.Tracer

  def index(conn, _params) do
    ctx = conn.assigns.otel_ctx
    Tracer.log(:info, ctx, "Processing request started")

    child_ctx = Tracer.start_span("test_action", ctx)
    child_ctx = Tracer.add_event("processing_started", child_ctx)

    child_ctx = perform_operation(child_ctx)

    Tracer.log(:debug, child_ctx, "Operation completed", %{duration_ms: 100})

    _ = Tracer.end_span(child_ctx)
    text(conn, "OK")
  end

  defp perform_operation(parent_ctx) do
    op_ctx = Tracer.start_span("database_operation", parent_ctx)
    :timer.sleep(100)
    Tracer.log(:info, op_ctx, "Executing database query", %{query: "SELECT * FROM users"})
    op_ctx = Tracer.add_event("query_executed", op_ctx, %{query: "SELECT * FROM users"})
    Tracer.end_span(op_ctx)
  end
end
