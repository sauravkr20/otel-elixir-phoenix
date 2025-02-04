defmodule OtelDemoWeb.TestController do
  use OtelDemoWeb, :controller
  alias OtelDemoWeb.Tracer

  def index(conn, _params) do
    ctx = conn.assigns.otel_ctx

    # Start a child span for the controller action, ensuring the parent's span is used
    child_ctx = Tracer.start_span("test_action", ctx)
    child_ctx = Tracer.add_event("processing_started", child_ctx)

    # Perform nested operation with its own span
    child_ctx = perform_operation(child_ctx)

    # End the child span and return to the parent (root) context
    _ = Tracer.end_span(child_ctx)
    text(conn, "OK")
  end

  defp perform_operation(parent_ctx) do
    op_ctx = Tracer.start_span("database_operation", parent_ctx)
    :timer.sleep(100)
    op_ctx = Tracer.add_event("query_executed", op_ctx, %{query: "SELECT * FROM users"})
    Tracer.end_span(op_ctx)
  end
end
