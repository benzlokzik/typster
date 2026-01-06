defmodule TypsterWeb.Components.UI.Button do
  @moduledoc """
  Button component following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders a button with the given variant and size.

  ## Variants

  * `default` - Indigo background with white text
  * `ghost` - Transparent with gray hover state
  * `outline` - Gray border with gray hover state
  * `link` - Text button with indigo color and underline
  * `destructive` - Red background for destructive actions

  ## Sizes

  * `default` - h-10 px-4 py-2
  * `sm` - h-9 px-3
  * `lg` - h-11 px-8
  * `icon` - h-10 w-10 (square icon button)

  ## Examples

      <.button>Click me</.button>
      <.button variant="ghost">Cancel</.button>
      <.button size="sm">Small button</.button>
      <.button variant="outline">Outline</.button>
      <.button variant="destructive">Delete</.button>
      <.button size="icon">
        <.icon name="hero-plus" />
      </.button>
  """
  attr :type, :string, default: "button"

  attr :variant, :string,
    default: "default",
    values: ["default", "ghost", "outline", "link", "destructive"]

  attr :size, :string, default: "default", values: ["default", "sm", "lg", "icon"]
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        button_classes(@variant, @size),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_classes(variant, size) do
    base_classes =
      "inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none"

    variant_classes = %{
      "default" => "bg-indigo-600 text-white hover:bg-indigo-700",
      "ghost" => "hover:bg-gray-100 hover:text-gray-900 text-gray-700",
      "outline" => "border border-gray-200 bg-transparent hover:bg-gray-100 text-gray-700",
      "link" => "text-indigo-600 underline-offset-4 hover:underline",
      "destructive" => "bg-red-600 text-white hover:bg-red-700"
    }

    size_classes = %{
      "default" => "h-10 px-4 py-2",
      "sm" => "h-9 rounded-md px-3",
      "lg" => "h-11 rounded-md px-8",
      "icon" => "h-10 w-10"
    }

    [base_classes, variant_classes[variant], size_classes[size]]
  end
end
