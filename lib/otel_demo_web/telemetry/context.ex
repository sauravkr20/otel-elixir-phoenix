defmodule OtelDemoWeb.Context do
  @moduledoc """
  Represents a node in the span context tree.
  Each node stores its own span_ctx, a reference to its parent,
  and any child contexts.
  """
  defstruct [:span_ctx, :parent, children: []]

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
