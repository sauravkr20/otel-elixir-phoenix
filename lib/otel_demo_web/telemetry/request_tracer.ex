defmodule OtelDemoWeb.Plugs.RequestTracer do
  @behaviour Plug
  require OpenTelemetry.Tracer
  import Plug.Conn
  require Logger
  alias OtelDemoWeb.Context

  def init(opts), do: opts

  def call(conn, _opts) do
    url_path = "#{conn.scheme}://#{conn.host}#{conn.request_path}"
    operation_name = "#{conn.method} #{url_path}"

    ctx = Context.from_current()
    {ctx, span_id, trace_id} = OtelDemoWeb.Tracer.start_span(operation_name, ctx)

    conn = assign(conn, :otel_ctx, ctx)

    register_before_send(conn, fn conn ->
      Logger.info("Completing request: #{operation_name} | Span ID: #{span_id} | Trace ID: #{trace_id}")
      conn
    end)
  end
end
