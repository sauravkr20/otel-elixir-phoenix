defmodule OtelDemoWeb.Context do
  @moduledoc """
  Tree-based context management for distributed tracing
  """
  defstruct [
    :span_ctx,
    :parent,
    children: []
  ]

  def new_root do
    %__MODULE__{
      span_ctx: nil,
      parent: nil,
      children: []
    }
  end

  def new_node(span_ctx, parent) do
    %__MODULE__{
      span_ctx: span_ctx,
      parent: parent,
      children: []
    }
  end
end
