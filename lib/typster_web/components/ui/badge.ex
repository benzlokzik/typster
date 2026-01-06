defmodule TypsterWeb.Components.UI.Badge do
  @moduledoc """
  Badge component following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders a badge with the given variant.

  ## Variants

  * `default` - Gray background
  * `secondary` - Light gray background
  * `outline` - Gray border with transparent background
  * `destructive` - Red background
  * `success` - Green background
  * `warning` - Yellow background

  ## Examples

      <.badge>Default</.badge>
      <.badge variant="secondary">Secondary</.badge>
      <.badge variant="success">Success</.badge>
      <.badge variant="destructive">Error</.badge>
  """
  attr :variant, :string,
    default: "default",
    values: ["default", "secondary", "outline", "destructive", "success", "warning"]

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <div class={[
      badge_classes(@variant),
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp badge_classes(variant) do
    base_classes =
      "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors"

    variant_classes = %{
      "default" => "border border-transparent bg-gray-900 text-gray-50 hover:bg-gray-900/80",
      "secondary" => "border border-transparent bg-gray-100 text-gray-900 hover:bg-gray-200",
      "outline" => "border border-gray-200 text-gray-950",
      "destructive" => "border border-transparent bg-red-600 text-white hover:bg-red-700",
      "success" => "border border-transparent bg-green-600 text-white hover:bg-green-700",
      "warning" => "border border-transparent bg-yellow-500 text-white hover:bg-yellow-600"
    }

    [base_classes, variant_classes[variant]]
  end
end
