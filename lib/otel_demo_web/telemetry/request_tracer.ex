defmodule OtelDemoWeb.Plugs.RequestTracer do
  @behaviour Plug
  require OpenTelemetry.Tracer
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Process.delete(:otel_current_span)
    url_path = "#{conn.scheme}://#{conn.host}#{conn.request_path}"
    operation_name = "#{conn.method} #{url_path}"

    parent_span_ctx = Process.get(:otel_current_span)
    parent_span_id = case parent_span_ctx do
      nil -> "no_parent_span"
      ctx -> OpenTelemetry.Span.hex_span_id(ctx)
    end

    OpenTelemetry.Tracer.with_span operation_name, %{attributes: %{
      "http.method" => conn.method,
      "http.url" => url_path
    }} do
      span_ctx = OpenTelemetry.Tracer.current_span_ctx()
      span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
      trace_id = case OpenTelemetry.Tracer.current_span_ctx() do
        :undefined -> "no_trace_id"
        ctx -> OpenTelemetry.Span.hex_trace_id(ctx)
      end

      Logger.info("Starting span: #{operation_name} | Name: #{operation_name} | Span ID: #{span_id} | Trace ID: #{trace_id} | Parent Span ID: #{parent_span_id}")
      Process.put(:otel_current_span, span_ctx)

      conn = register_before_send(conn, fn conn ->
        Logger.info("Completing span: #{operation_name} | Name: #{operation_name} | Span ID: #{span_id} | Trace ID: #{trace_id} | Parent Span ID: #{parent_span_id}")
        Process.delete(:otel_current_span)
        conn
      end)

      conn
    end
  end
end
