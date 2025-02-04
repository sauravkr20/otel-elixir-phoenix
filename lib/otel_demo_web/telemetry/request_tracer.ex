defmodule OtelDemoWeb.Plugs.RequestTracer do
  @moduledoc """
  Plug for handling request-level tracing
  """
  @behaviour Plug
  import Plug.Conn
  require Logger
  alias OtelDemoWeb.{Context, Tracer}

  def init(opts), do: opts

  def call(conn, _opts) do
    root_ctx = Context.new_root()
    req_name = "#{conn.method} #{conn.request_path}"

    # Start root span
    ctx = Tracer.start_span(req_name, root_ctx)

    conn
    |> assign(:otel_ctx, ctx)
    |> register_before_send(fn conn ->
      # Close entire span tree
      close_all_spans(conn.assigns.otel_ctx)
      log_request_completion(conn, req_name)
      conn
    end)
  end

  defp close_all_spans(%Context{parent: parent} = ctx) do
    # Recursively close all spans in reverse order
    ctx = Tracer.end_span(ctx)
    if parent, do: close_all_spans(parent), else: ctx
  end

  defp log_request_completion(conn, name) do
    Logger.info("""
    Completed request: #{name}
    │ Status: #{conn.status}
    """)
  end
end


# TODO add proper attributes to the parent span and trace
