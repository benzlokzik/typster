defmodule TypsterWeb.Components.UI.Dialog do
  @moduledoc """
  Dialog (modal) component following the mira design system.
  """
  use Phoenix.Component
  import TypsterWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a dialog overlay and container.

  ## Examples

      <.dialog id="my-dialog" open={@dialog_open} on_close="close_dialog">
        <.dialog_header>
          <.dialog_title>Dialog Title</.dialog_title>
          <.dialog_description>Dialog description</.dialog_description>
        </.dialog_header>
        <.dialog_body>
          <p>Dialog content goes here</p>
        </.dialog_body>
        <.dialog_footer>
          <.button variant="ghost" phx-click="close_dialog">Cancel</.button>
          <.button>Save</.button>
        </.dialog_footer>
      </.dialog>
  """
  attr :id, :string, required: true
  attr :open, :boolean, required: true
  attr :on_close, :string, required: true
  attr :size, :string, default: "md", values: ["sm", "md", "lg", "xl", "full"]
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def dialog(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "relative z-50",
        !@open && "hidden"
      ]}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
    >
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm transition-opacity"
        phx-click={@on_close}
      >
      </div>

      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div
            class={[
              "relative w-full bg-white rounded-lg shadow-2xl",
              dialog_size(@size),
              "animate-in fade-in-0 zoom-in-95 duration-200",
              @class
            ]}
            phx-click-away={@on_close}
          >
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp dialog_size("sm"), do: "max-w-sm"
  defp dialog_size("md"), do: "max-w-md"
  defp dialog_size("lg"), do: "max-w-lg"
  defp dialog_size("xl"), do: "max-w-xl"
  defp dialog_size("full"), do: "max-w-full mx-4"

  @doc """
  Renders the dialog header section.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def dialog_header(assigns) do
    ~H"""
    <div class={["flex flex-col space-y-1.5 p-6 border-b border-gray-200", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the dialog title.
  """
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def dialog_title(assigns) do
    ~H"""
    <h2 class={["text-lg font-semibold text-gray-900", @class]} id={@id && "#{@id}-title"}>
      {render_slot(@inner_block)}
    </h2>
    """
  end

  @doc """
  Renders the dialog description.
  """
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def dialog_description(assigns) do
    ~H"""
    <p class={["text-sm text-gray-500", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders the dialog body section.
  """
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def dialog_body(assigns) do
    ~H"""
    <div class={["p-6", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the dialog footer section with action buttons.
  """
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def dialog_footer(assigns) do
    ~H"""
    <div class={["flex items-center justify-end gap-2 p-6 border-t border-gray-200", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the dialog close button.
  """
  attr :on_close, :string, required: true

  def dialog_close(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_close}
      class="absolute right-4 top-4 rounded-sm opacity-70 ring-offset-gray-900 transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-gray-950 focus:ring-offset-2 disabled:pointer-events-none"
    >
      <.icon name="hero-x-mark" class="w-4 h-4" />
      <span class="sr-only">Close</span>
    </button>
    """
  end
end
