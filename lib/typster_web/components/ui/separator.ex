defmodule TypsterWeb.Components.UI.Separator do
  @moduledoc """
  Separator component following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders a horizontal or vertical separator line.

  ## Examples

      <.separator />
      <.separator orientation="vertical" />
  """
  attr :orientation, :string, default: "horizontal", values: ["horizontal", "vertical"]
  attr :class, :string, default: ""

  def separator(assigns) do
    ~H"""
    <div
      class={[
        separator_classes(@orientation),
        @class
      ]}
      role="separator"
    >
    </div>
    """
  end

  defp separator_classes("horizontal") do
    "shrink-0 bg-gray-200 h-[1px] w-full"
  end

  defp separator_classes("vertical") do
    "shrink-0 bg-gray-200 h-full w-[1px]"
  end
end
