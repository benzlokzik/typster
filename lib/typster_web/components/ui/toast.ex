defmodule TypsterWeb.Components.UI.Toast do
  @moduledoc """
  Toast notification component following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders a toast notification container with toasts.

  ## Kinds

  * `default` - Gray styling
  * `success` - Green styling
  * `error` - Red styling
  * `warning` - Yellow styling

  ## Examples

      <.toast_container>
        <.toast title="Success" kind="success">
          Your changes have been saved successfully.
        </.toast>
        <.toast title="Error" kind="error">
          Something went wrong. Please try again.
        </.toast>
      </.toast_container>
  """
  attr :id, :string, default: "toast-container"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def toast_container(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "fixed bottom-4 right-4 z-50 flex flex-col gap-2 pointer-events-none",
        @class
      ]}
    >
      <div class="pointer-events-auto">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a single toast notification.

  ## Attributes

  * `title` - The toast title (optional)
  * `kind` - The toast kind (default, success, error, warning)
  * `duration` - Auto-dismiss duration in ms (0 for no auto-dismiss)
  * `on_dismiss` - Event to trigger when dismissed
  """
  attr :id, :string, default: nil
  attr :title, :string, default: nil
  attr :kind, :string, default: "default", values: ["default", "success", "error", "warning"]
  attr :duration, :integer, default: 5000
  attr :on_dismiss, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def toast(assigns) do
    assigns = assign(assigns, :id, assigns.id || "toast-#{System.unique_integer()}")

    ~H"""
    <div
      id={@id}
      phx-mounted={@duration > 0 && "setTimeout(() => window.dispatchEvent(new CustomEvent('dismiss-toast', { detail: { id: '#{@id}' } })), #{@duration})"}
      class={[
        "flex items-start gap-3 px-4 py-3 bg-white rounded-lg shadow-lg border",
        toast_kind_border(@kind),
        @class
      ]}
      data-kind={@kind}
    >
      <div class={[
        "w-2 h-2 rounded-full flex-shrink-0 mt-2",
        toast_kind_color(@kind)
      ]}>
      </div>
      <div class="flex-1 min-w-0">
        {if @title do %}
          <h4 class="text-sm font-semibold text-gray-900">{@title}</h4>
        <% end %>
        <p class="text-sm text-gray-600">{render_slot(@inner_block)}</p>
      </div>
      <button
        type="button"
        phx-click="dismiss_toast"
        phx-value-id={@id}
        class="text-gray-400 hover:text-gray-600 transition-colors flex-shrink-0"
        aria-label="Close"
      >
        <.icon name="hero-x-mark" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  defp toast_kind_border("success"), do: "border-green-200"
  defp toast_kind_border("error"), do: "border-red-200"
  defp toast_kind_border("warning"), do: "border-yellow-200"
  defp toast_kind_border(_), do: "border-gray-200"

  defp toast_kind_color("success"), do: "bg-green-500"
  defp toast_kind_color("error"), do: "bg-red-500"
  defp toast_kind_color("warning"), do: "bg-yellow-500"
  defp toast_kind_color(_), do: "bg-gray-500"

  @doc """
  Renders a dismiss button for toast notifications.
  """
  attr :id, :string, required: true
  attr :on_dismiss, :string, default: nil

  def toast_dismiss_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_dismiss || "dismiss_toast"}
      phx-value-id={@id}
      class="text-gray-400 hover:text-gray-600 transition-colors"
      aria-label="Dismiss"
    >
      <.icon name="hero-x-mark" class="w-4 h-4" />
    </button>
    """
  end
end
