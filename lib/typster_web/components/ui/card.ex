defmodule TypsterWeb.Components.UI.Card do
  @moduledoc """
  Card component following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders a card container with optional header, content, and footer.

  ## Examples

      <.card>
        <.card_header>
          <.card_title>Card Title</.card_title>
          <.card_description>Card description goes here</.card_description>
        </.card_header>
        <.card_content>
          <p>Card content goes here</p>
        </.card_content>
        <.card_footer>
          <.button>Action</.button>
        </.card_footer>
      </.card>
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["rounded-lg border border-gray-200 bg-white text-gray-950 shadow-sm", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the card header section.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_header(assigns) do
    ~H"""
    <div class={["flex flex-col space-y-1.5 p-6", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the card title.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_title(assigns) do
    ~H"""
    <h3 class={["text-2xl font-semibold leading-none tracking-tight", @class]}>
      {render_slot(@inner_block)}
    </h3>
    """
  end

  @doc """
  Renders the card description (subtitle).
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_description(assigns) do
    ~H"""
    <p class={["text-sm text-gray-500", @class]}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders the card content section.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_content(assigns) do
    ~H"""
    <div class={["p-6 pt-0", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the card footer section.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card_footer(assigns) do
    ~H"""
    <div class={["flex items-center p-6 pt-0", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
