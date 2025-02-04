defmodule OtelDemoWeb.Tracer do
  @moduledoc """
  Tree-based OpenTelemetry tracer with proper context management
  """
  require Logger
  require OpenTelemetry.Tracer

  alias OtelDemoWeb.Context

  @doc """
  Starts a new span and updates the context tree
  """
  def start_span(name, %Context{} = ctx) do
    parent_span = ctx.span_ctx
    span_ctx = OpenTelemetry.Tracer.start_span(name, %{parent: parent_span})

    new_node = Context.new_node(span_ctx, ctx)
    updated_ctx = put_in(ctx.children, [new_node | ctx.children])

    log_span_start(name, span_ctx, parent_span)
    new_node
  end

  @doc """
  Ends a span and returns to parent context
  """
  def end_span(%Context{span_ctx: nil} = ctx), do: ctx

  def end_span(%Context{span_ctx: span_ctx, parent: parent} = ctx) do
    log_span_end(span_ctx, parent)
    OpenTelemetry.Span.end_span(span_ctx)
    parent || Context.new_root()
  end

  @doc """
  Adds event to current span
  """
  def add_event(name, %Context{span_ctx: span_ctx} = ctx, attrs \\ %{}) do
    if span_ctx do
      OpenTelemetry.Span.add_event(span_ctx, name, attrs)
      log_event(name, span_ctx)
    else
      Logger.error("Attempted to add event #{name} to nil span")
    end
    ctx
  end

  defp log_span_start(name, span_ctx, parent_span) do
    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
    parent_id = if parent_span, do: OpenTelemetry.Span.hex_span_id(parent_span), else: "no_parent_span"

    Logger.info("""
    Starting span: #{name}
    │ Span ID: #{span_id}
    │ Trace ID: #{trace_id}
    └ Parent Span ID: #{parent_id}
    """)
  end

  defp log_span_end(span_ctx, parent) do
    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
    parent_id = if parent && parent.span_ctx,
                do: OpenTelemetry.Span.hex_span_id(parent.span_ctx),
                else: "no_parent_span"

    Logger.info("""
    Completing span
    │ Span ID: #{span_id}
    │ Trace ID: #{trace_id}
    └ Parent Span ID: #{parent_id}
    """)
  end

  defp log_event(name, span_ctx) do
    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)

    Logger.info("""
    Event: #{name}
    │ Span ID: #{span_id}
    └ Trace ID: #{trace_id}
    """)
  end
end
