defmodule OtelDemoWeb.Context do
  defstruct [:span_ctx]

  def from_current do
    %__MODULE__{
      span_ctx: OpenTelemetry.Tracer.current_span_ctx()
    }
  end

  def new(span_ctx) do
    %__MODULE__{
      span_ctx: span_ctx
    }
  end
end
