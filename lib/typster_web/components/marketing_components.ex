defmodule TypsterWeb.MarketingComponents do
  @moduledoc """
  Shared function components for marketing pages.
  """

  use Phoenix.Component

  attr :class, :string, default: "mk-feat"
  attr :icon_class, :string, default: "mk-feat-icon"
  attr :icon, :string, required: true
  slot :title, required: true
  slot :body, required: true

  def icon_card(assigns) do
    ~H"""
    <div class={@class}>
      <div class={@icon_class}><i data-lucide={@icon}></i></div>
      <h3>{render_slot(@title)}</h3>
      <p>{render_slot(@body)}</p>
    </div>
    """
  end
end
