defmodule OtelDemoWeb.Tracer do
  require Logger
  require OpenTelemetry.Tracer

  def start_span(name, ctx) do
    parent_ctx = ctx.span_ctx

    # Start new span with explicit parent context
    span_ctx = OpenTelemetry.Tracer.start_span(name, %{parent: parent_ctx})

    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)

    # Get parent ID after span creation
    parent_id = case parent_ctx do
      nil -> "no_parent_span"
      :undefined -> "no_parent_span"
      _ -> OpenTelemetry.Span.hex_span_id(parent_ctx)
    end

    Logger.info("Starting span: #{name} | Span ID: #{span_id} | Trace ID: #{trace_id} | Parent Span ID: #{parent_id}")

    new_ctx = %{ctx | span_ctx: span_ctx, parent_ctx: parent_ctx}
    {new_ctx, span_id, trace_id}
  end

  def end_span({ctx, span_id, trace_id}) do
    case ctx.span_ctx do
      nil ->
        Logger.error("No span context found to end")
        ctx
      :undefined ->
        Logger.error("Undefined span context to end")
        ctx
      span_ctx ->
        parent_id = case ctx.parent_ctx do
          nil -> "no_parent_span"
          :undefined -> "no_parent_span"
          parent_ctx -> OpenTelemetry.Span.hex_span_id(parent_ctx)
        end

        Logger.info("Completing span | Span ID: #{span_id} | Trace ID: #{trace_id} | Parent Span ID: #{parent_id}")
        OpenTelemetry.Span.end_span(span_ctx)
        %{ctx | span_ctx: ctx.parent_ctx, parent_ctx: nil}
    end
  end

  def add_event(name, ctx, attributes \\ %{}) do
    case ctx.span_ctx do
      nil ->
        Logger.error("No span context found for event: #{name}")
        ctx
      :undefined ->
        Logger.error("Undefined span context for event: #{name}")
        ctx
      span_ctx ->
        span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
        trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)

        Logger.info("Event: #{name} | Span ID: #{span_id} | Trace ID: #{trace_id}")
        OpenTelemetry.Span.add_event(span_ctx, name, attributes)
        ctx
    end
  end
end
