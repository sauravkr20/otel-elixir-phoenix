defmodule OtelDemoWeb.Tracer do
  @moduledoc """
  Tree-based OpenTelemetry tracer that manages hierarchical span contexts.
  Before starting a child span, if a parent exists, we set it as the current active span.
  This ensures that child spans use the proper parent.
  """
  require Logger
  require OpenTelemetry.Tracer

  alias OtelDemoWeb.Context

  @doc """
  Starts a new span under the given context.
  If a parent span exists, it’s set as active so that the new span
  is created as a child.
  """
  def start_span(name, %Context{span_ctx: parent_span} = ctx) do
    # If there is a parent, ensure it's active
    if parent_span do
      OpenTelemetry.Tracer.set_current_span(parent_span)
    end

    # Start the new span with the parent context
    span_ctx = OpenTelemetry.Tracer.start_span(name, %{parent: parent_span})

    # Create a new context node for this span
    new_node = Context.new_node(span_ctx, ctx)

    # Optionally update children (if you need to inspect the tree later)
    _updated_ctx = put_in(ctx.children, [new_node | ctx.children])

    log_span_start(name, span_ctx, parent_span)
    new_node
  end

  @doc """
  Ends the current span and returns the parent context.
  If no span exists, returns the context unchanged.
  """
  def end_span(%Context{span_ctx: nil} = ctx), do: ctx

  def end_span(%Context{span_ctx: span_ctx, parent: parent} = ctx) do
    log_span_end(span_ctx, parent)
    OpenTelemetry.Span.end_span(span_ctx)
    parent || Context.new_root()
  end

  @doc """
  Adds an event to the current span.
  """
  def add_event(name, %Context{span_ctx: span_ctx} = ctx, attrs \\ %{}) do
    if span_ctx do
      OpenTelemetry.Span.add_event(span_ctx, name, attrs)
      log_event(name, span_ctx)
    else
      # Logger.error("Attempted to add event #{name} to nil span")
    end
    ctx
  end

  defp log_span_start(name, span_ctx, parent_span) do
    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
    parent_id =
      if parent_span do
        OpenTelemetry.Span.hex_span_id(parent_span)
      else
        "no_parent_span"
      end

    # Logger.info("""
    # Starting span: #{name}
    #   │ Span ID: #{span_id}
    #   │ Trace ID: #{trace_id}
    #   └ Parent Span ID: #{parent_id}
    # """)
  end

  defp log_span_end(span_ctx, parent) do
    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
    parent_id =
      if parent && parent.span_ctx do
        OpenTelemetry.Span.hex_span_id(parent.span_ctx)
      else
        "no_parent_span"
      end

    # Logger.info("""
    # Completing span
    #   │ Span ID: #{span_id}
    #   │ Trace ID: #{trace_id}
    #   └ Parent Span ID: #{parent_id}
    # """)
  end

  defp log_event(name, span_ctx) do
    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)

    # Logger.info("""
    # Event: #{name}
    #   │ Span ID: #{span_id}
    #   └ Trace ID: #{trace_id}
    # """)
  end

  def log(level, %Context{span_ctx: span_ctx} = ctx, message, attrs \\ %{}) do
    if span_ctx do
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:nanosecond)

      event_attrs = Map.merge(%{
        "log.message" => message,
        "log.severity" => Atom.to_string(level),
        "log.timestamp" => timestamp
      }, attrs)

      OpenTelemetry.Span.add_event(span_ctx, "log", event_attrs)

      log_message(level, message, span_ctx, attrs)
    else
      Logger.error("Attempted to add log to nil span: #{message}")
    end
  end

  defp log_message(level, message, span_ctx, attrs) do
    span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
    trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)

    log_entry = %{
      level: level,
      message: message,
      span_id: span_id,
      trace_id: trace_id,
      attributes: attrs
    }

    case level do
      :error -> Logger.error(log_entry)
      :warn -> Logger.warning(log_entry)
      :info -> Logger.info(log_entry)
      :debug -> Logger.debug(log_entry)
      _ -> Logger.info(log_entry)
    end
  end

  def format(level, message, timestamp, metadata) do
    metadata
    |> sanitize_metadata()
    |> Map.put(:timestamp, DateTime.utc_now())
    |> Map.put(:level, level)
    |> Map.put(:message, to_string(message))
    |> Jason.encode!()
  rescue
    _ -> Jason.encode!(%{error: "Failed to format log entry"})
  end

  defp sanitize_metadata(metadata) do
    metadata
    |> Enum.map(fn
      {:request_id, value} -> {:request_id, to_string(value)}
      {key, value} -> {key, sanitize_value(value)}
    end)
    |> Enum.into(%{})
  end

  defp sanitize_value(value) when is_tuple(value), do: Tuple.to_list(value)
  defp sanitize_value(%_{} = struct), do: struct |> Map.from_struct() |> sanitize_value()
  defp sanitize_value(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, sanitize_value(v)} end)
  defp sanitize_value(list) when is_list(list), do: Enum.map(list, &sanitize_value/1)
  defp sanitize_value(value), do: value


end
