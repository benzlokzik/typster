defmodule TypsterWeb.Components.UI.Skeleton do
  @moduledoc """
  Skeleton component for loading states following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders a skeleton element for loading states.

  ## Examples

      <.skeleton class="h-4 w-64" />
      <.skeleton class="h-8 w-full" />
      <.skeleton_card />
  """
  attr :class, :string, default: "h-4 w-full"

  def skeleton(assigns) do
    ~H"""
    <div class={["animate-pulse rounded-md bg-gray-100", @class]}></div>
    """
  end

  @doc """
  Renders a complete skeleton card for loading card states.
  """
  def skeleton_card(assigns) do
    ~H"""
    <div class="space-y-4 p-6 bg-white rounded-lg border border-gray-200">
      <div class="flex items-center space-x-4">
        <.skeleton class="h-12 w-12 rounded-full" />
        <div class="space-y-2 flex-1">
          <.skeleton class="h-4 w-32" />
          <.skeleton class="h-3 w-48" />
        </div>
      </div>
      <.skeleton class="h-32 w-full" />
      <div class="space-y-2">
        <.skeleton class="h-4 w-3/4" />
        <.skeleton class="h-4 w-1/2" />
      </div>
    </div>
    """
  end

  @doc """
  Renders a skeleton list for loading list states.
  """
  attr :count, :integer, default: 5

  def skeleton_list(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= for _ <- 1..@count do %>
        <div class="flex items-center space-x-4 p-4 border border-gray-200 rounded-lg">
          <.skeleton class="h-10 w-10 rounded-md" />
          <div class="space-y-2 flex-1">
            <.skeleton class="h-4 w-64" />
            <.skeleton class="h-3 w-48" />
          </div>
          <.skeleton class="h-8 w-20" />
        </div>
      <% end %>
    </div>
    """
  end
end
