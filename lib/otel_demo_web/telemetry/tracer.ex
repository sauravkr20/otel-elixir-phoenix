defmodule OtelDemoWeb.Tracer do
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
      @spans {__ENV__.function, name}
    end
  end

  defmacro __before_compile__(env) do
    spans = Module.get_attribute(env.module, :spans)

    Enum.map(spans, fn {{name, arity}, span_name} ->
      args = Enum.map(1..arity, &Macro.var(:"arg#{&1}", nil))

      quote do
        defoverridable [{unquote(name), unquote(arity)}]

        def unquote(name)(unquote_splicing(args)) do
          OpenTelemetry.Tracer.with_span unquote(span_name), %{
            attributes: %{
              module: __MODULE__,
              function: unquote(name),
              arity: unquote(arity)
            }
          } do
            span_ctx = OpenTelemetry.Tracer.current_span_ctx()
            Process.put(:otel_current_span, span_ctx)

            try do
              super(unquote_splicing(args))
            after
              Process.delete(:otel_current_span)
            end
          end
        end
      end
    end)
  end
end
