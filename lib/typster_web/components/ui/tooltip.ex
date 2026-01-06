defmodule TypsterWeb.Components.UI.Tooltip do
  @moduledoc """
  Tooltip component following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders a tooltip that shows on hover.

  ## Examples

      <.tooltip content="This is a tooltip">
        <button>Hover me</button>
      </.tooltip>

      <.tooltip content="Longer tooltip text" position="top">
        <.button>Top tooltip</.button>
      </.tooltip>
  """
  attr :content, :string, required: true
  attr :position, :string, default: "top", values: ["top", "bottom", "left", "right"]
  attr :class, :string, default: ""
  attr :delay, :integer, default: 200

  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <div
      class="group relative inline-block"
      data-tooltip-delay={@delay}
    >
      {render_slot(@inner_block)}

      <div
        class={[
          "absolute z-50 px-3 py-2 text-sm text-gray-900 bg-white",
          "rounded-md shadow-lg border border-gray-200",
          "opacity-0 invisible group-hover:opacity-100 group-hover:visible",
          "transition-all duration-200 pointer-events-none",
          "whitespace-nowrap",
          tooltip_position(@position),
          @class
        ]}
        role="tooltip"
      >
        {@content}
      </div>
    </div>
    """
  end

  defp tooltip_position("top") do
    "bottom-full left-1/2 -translate-x-1/2 mb-2"
  end

  defp tooltip_position("bottom") do
    "top-full left-1/2 -translate-x-1/2 mt-2"
  end

  defp tooltip_position("left") do
    "right-full top-1/2 -translate-y-1/2 mr-2"
  end

  defp tooltip_position("right") do
    "left-full top-1/2 -translate-y-1/2 ml-2"
  end
end
