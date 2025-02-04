defmodule OtelDemoWeb.TestController do
  use OtelDemoWeb, :controller
  alias OtelDemoWeb.Tracer
  require Logger

  def index(conn, _params) do
    ctx = conn.assigns.otel_ctx
    IO.inspect(ctx, label: "Context")
    span_info = Tracer.start_span("test_action", ctx)
    {ctx, _, _} = span_info

    {ctx, _result} = do_something(ctx)

    ctx = Tracer.end_span(span_info)
    text(conn, "Test endpoint")
  end

  defp do_something(ctx) do
    span_info = Tracer.start_span("do_something", ctx)
    {ctx, _, _} = span_info

    ctx = Tracer.add_event("doing_something", ctx)
    {ctx, _result} = nested_operation(ctx)

    ctx = Tracer.end_span(span_info)
    {ctx, :ok}
  end

  defp nested_operation(ctx) do
    span_info = Tracer.start_span("nested_operation", ctx)
    {ctx, _, _} = span_info

    ctx = Tracer.add_event("nested_operation_started", ctx)
    :timer.sleep(100)
    ctx = Tracer.add_event("nested_operation_completed", ctx)

    ctx = Tracer.end_span(span_info)
    {ctx, :ok}
  end
end
