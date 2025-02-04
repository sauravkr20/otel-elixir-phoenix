
defmodule OtelDemoWeb.Context do
  defstruct [:span_ctx, :parent_ctx]

  def from_current do
    current_ctx = OpenTelemetry.Tracer.current_span_ctx()
    %__MODULE__{
      span_ctx: current_ctx,
      parent_ctx: nil
    }
  end

  def new(span_ctx) do
    %__MODULE__{
      span_ctx: span_ctx,
      parent_ctx: nil
    }
  end
end
