defmodule TypsterWeb.Components.UI.Breadcrumb do
  @moduledoc """
  Breadcrumb component following the mira design system.
  """
  use Phoenix.Component
  import TypsterWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a breadcrumb navigation.

  ## Examples

      <.breadcrumb>
        <.breadcrumb_item>
          <.breadcrumb_link navigate="/projects">Projects</.breadcrumb_link>
        </.breadcrumb_item>
        <.breadcrumb_separator />
        <.breadcrumb_item>
          <.breadcrumb_page>My Project</.breadcrumb_page>
        </.breadcrumb_item>
      </.breadcrumb>
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def breadcrumb(assigns) do
    ~H"""
    <nav class={["flex items-center space-x-1 text-sm", @class]} aria-label="Breadcrumb">
      {render_slot(@inner_block)}
    </nav>
    """
  end

  @doc """
  Renders a breadcrumb item (container).
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def breadcrumb_item(assigns) do
    ~H"""
    <li class={["flex items-center", @class]}>
      {render_slot(@inner_block)}
    </li>
    """
  end

  @doc """
  Renders a breadcrumb link (clickable).
  """
  attr :navigate, :string, required: true
  attr :patch, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def breadcrumb_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      patch={@patch}
      class={[
        "transition-colors hover:text-gray-900 text-gray-600",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a breadcrumb page (current page, non-clickable).
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def breadcrumb_page(assigns) do
    ~H"""
    <span class={["font-medium text-gray-900", @class]} aria-current="page">
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders a breadcrumb separator between items.
  """
  def breadcrumb_separator(assigns) do
    ~H"""
    <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-400 flex-shrink-0" />
    """
  end
end
