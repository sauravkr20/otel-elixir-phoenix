defmodule OtelDemoWeb.Tracer do
  @moduledoc """
  Automatic span lifecycle and context management through macros.
  """

  require Logger

  defmacro __using__(_opts) do
    quote do
      require OpenTelemetry.Tracer
      import OtelDemoWeb.Tracer

      Module.register_attribute(__MODULE__, :spans, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro span(name) do
    quote bind_quoted: [name: name] do
      Logger.info("Registering span: #{name} for #{inspect(__ENV__.function)}")
      @spans {__ENV__.function, name}
    end
  end

  defp get_parent_span_id do
    case Process.get(:otel_current_span) do
      nil -> nil
      span_ctx -> OpenTelemetry.Span.hex_span_id(span_ctx)
    end
  end

  defmacro __before_compile__(env) do
    spans = Module.get_attribute(env.module, :spans)
    Logger.info("Compiling spans for #{inspect(env.module)}: #{inspect(spans)}")

    definitions = spans
    |> Enum.map(fn {{name, arity}, span_name} ->
      args = Enum.map(1..arity, &Macro.var(:"arg#{&1}", nil))

      quote do
        defoverridable [{unquote(name), unquote(arity)}]

        def unquote(name)(unquote_splicing(args)) do
          parent_span_ctx = Process.get(:otel_current_span)
          trace_ctx = OpenTelemetry.Ctx.get_current()

          span_ctx = OpenTelemetry.Tracer.current_span_ctx()
          request_span_id = case span_ctx do
            nil -> nil
            ctx -> OpenTelemetry.Span.hex_span_id(ctx)
          end
          trace_id = OpenTelemetry.Ctx.get_value(:"trace-id", trace_ctx) |> Base.encode16()

          # Store the current span as parent before creating new span
          parent_span_ctx = Process.get(:otel_current_span)
          parent_span_id = case parent_span_ctx do
            nil -> nil
            ctx -> OpenTelemetry.Span.hex_span_id(ctx)
          end

          span_info = "Starting span: #{unquote(span_name)} | " <>
                     "Name: #{unquote(span_name)} | " <>
                     "Span ID: #{request_span_id} | " <>
                     "Trace ID: #{trace_id}"

          span_info = if parent_span_id, do: span_info <> " | Parent Span ID: #{parent_span_id}", else: span_info
          Logger.info(span_info)

          # Create new span
          OpenTelemetry.Tracer.with_span unquote(span_name), %{
            attributes: %{
              module: __MODULE__,
              function: unquote(name),
              arity: unquote(arity),
              parent_span_id: parent_span_id
            }
          } do
            new_span_ctx = OpenTelemetry.Tracer.current_span_ctx()
            previous_span = Process.put(:otel_current_span, new_span_ctx)

            previous_span = Process.put(:otel_current_span, span_ctx)

            try do
              result = super(unquote_splicing(args))
              span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
              trace_id = OpenTelemetry.Ctx.get_value(:"trace-id", trace_ctx) |> Base.encode16()
              parent_id = get_parent_span_id()

              span_info = "Completed span: #{unquote(span_name)} | " <>
                         "Name: #{unquote(span_name)} | " <>
                         "Span ID: #{span_id} | " <>
                         "Trace ID: #{trace_id}"

              span_info = if parent_id, do: span_info <> " | Parent Span ID: #{parent_id}", else: span_info
              Logger.info(span_info)
              result
            rescue
              e ->
                span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
                Logger.error("Error in span: #{unquote(span_name)} | Span ID: #{span_id}")
                OpenTelemetry.Span.set_status(span_ctx, OpenTelemetry.Status.error("Error occurred"))
                OpenTelemetry.Span.record_exception(span_ctx, e, __STACKTRACE__)
                reraise e, __STACKTRACE__
            after
              Process.put(:otel_current_span, previous_span)
            end
          end
        end
      end
    end)

    quote do
      unquote_splicing(definitions)
    end
  end

  def add_event(name, attributes \\ %{}) do
    case Process.get(:otel_current_span) do
      nil ->
        Logger.error("No active span context found when adding event: #{name}")
        raise "No active span context found"
      span_ctx ->
        span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
        trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
        parent_id = get_parent_span_id()

        event_info = "Event: #{name} | Span ID: #{span_id} | Trace ID: #{trace_id}"
        event_info = if parent_id, do: "#{event_info} | Parent Span ID: #{parent_id}", else: event_info
        Logger.info(event_info)

        OpenTelemetry.Span.add_event(span_ctx, name, Map.merge(attributes, %{
          span_id: span_id,
          trace_id: trace_id,
          parent_span_id: parent_id
        }))
    end
  end

  def set_error(error, metadata \\ %{}) do
    case Process.get(:otel_current_span) do
      nil ->
        Logger.error("No active span context found when setting error")
        raise "No active span context found"
      span_ctx ->
        span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
        trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
        parent_id = get_parent_span_id()

        error_info = "Error | Span ID: #{span_id} | Trace ID: #{trace_id}"
        error_info = if parent_id, do: "#{error_info} | Parent Span ID: #{parent_id}", else: error_info
        Logger.error(error_info)

        OpenTelemetry.Span.set_status(span_ctx, OpenTelemetry.Status.error("Error occurred"))

        error_attrs = Map.merge(%{
          "error.type": error.__struct__,
          "error.message": Exception.message(error),
          span_id: span_id,
          trace_id: trace_id,
          parent_span_id: parent_id
        }, metadata)

        OpenTelemetry.Span.set_attributes(span_ctx, error_attrs)
        add_event("error", error_attrs)
    end
  end

  def mark_error(message, metadata \\ %{}) do
    case Process.get(:otel_current_span) do
      nil ->
        Logger.error("No active span context found when marking error")
        raise "No active span context found"
      span_ctx ->
        span_id = OpenTelemetry.Span.hex_span_id(span_ctx)
        trace_id = OpenTelemetry.Span.hex_trace_id(span_ctx)
        parent_id = get_parent_span_id()

        error_info = "Error: #{message} | Span ID: #{span_id} | Trace ID: #{trace_id}"
        error_info = if parent_id, do: "#{error_info} | Parent Span ID: #{parent_id}", else: error_info
        Logger.error(error_info)

        OpenTelemetry.Span.set_status(span_ctx, OpenTelemetry.Status.error(message))

        error_attrs = Map.merge(%{
          "error.message": message,
          span_id: span_id,
          trace_id: trace_id,
          parent_span_id: parent_id
        }, metadata)

        OpenTelemetry.Span.set_attributes(span_ctx, error_attrs)
        add_event("error", error_attrs)
    end
  end

  def set_attribute(key, value) do
    case Process.get(:otel_current_span) do
      nil ->
        Logger.error("No active span context found when setting attribute")
        raise "No active span context found"
      span_ctx ->
        OpenTelemetry.Span.set_attribute(span_ctx, key, value)
    end
  end

  def set_attributes(attributes) when is_map(attributes) do
    case Process.get(:otel_current_span) do
      nil ->
        Logger.error("No active span context found when setting attributes")
        raise "No active span context found"
      span_ctx ->
        OpenTelemetry.Span.set_attributes(span_ctx, attributes)
    end
  end
end
