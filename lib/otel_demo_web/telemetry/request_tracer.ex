defmodule OtelDemoWeb.Plugs.RequestTracer do
  @moduledoc """
  Plug for handling request-level tracing.
  Creates a root span for every request (with HTTP attributes),
  stores the context in the connection assigns, and closes all spans before sending response.
  """
  @behaviour Plug
  import Plug.Conn
  require Logger
  alias OtelDemoWeb.{Context, Tracer}

  def init(opts), do: opts

  def call(conn, _opts) do
    req_name = "#{conn.method} #{conn.request_path}"

    # Build a root context (span_ctx is nil in root)
    root_ctx = Context.new_root()

    # Create the root span: since root_ctx.span_ctx is nil, the new span is a root span.
    ctx = Tracer.start_span(req_name, root_ctx)

    # Set standard HTTP attributes on the root span.
    OpenTelemetry.Span.set_attributes(ctx.span_ctx, %{
      "http.method"    => conn.method,
      "http.route"     => conn.request_path,
      "http.target"    => conn.request_path,
      "http.scheme"    => to_string(conn.scheme),
      "net.host.name"  => conn.host,
      "net.host.port"  => conn.port
    })

    conn
    |> assign(:otel_ctx, ctx)
    |> register_before_send(fn conn ->
      # Recursively close all spans in the current context tree
      close_all_spans(conn.assigns.otel_ctx)
      log_request_completion(conn, req_name)
      conn
    end)
  end

  defp close_all_spans(%Context{} = ctx) do
    # First, close any child spans (iterate in reverse order)
    Enum.each(Enum.reverse(ctx.children), &close_all_spans/1)
    # Then close this span
    Tracer.end_span(ctx)
  end

  defp log_request_completion(conn, name) do
    Logger.info("""
    Completed request: #{name}
      │ Status: #{conn.status}
    """)
  end
end
