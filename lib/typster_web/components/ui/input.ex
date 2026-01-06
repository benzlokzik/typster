defmodule TypsterWeb.Components.UI.Input do
  @moduledoc """
  Input component following the mira design system.
  """
  use Phoenix.Component

  @doc """
  Renders an input field with the given type.

  ## Types

  * `text` - Standard text input (default)
  * `email` - Email input
  * `password` - Password input with obscured text
  * `number` - Numeric input
  * `search` - Search input

  ## Examples

      <.input name="email" type="email" placeholder="you@example.com" />
      <.input name="password" type="password" />
      <.input name="search" type="search" placeholder="Search..." />
  """
  attr :id, :any, default: nil
  attr :name, :any

  attr :type, :string,
    default: "text",
    values: ["text", "email", "password", "number", "search", "tel", "url", "date"]

  attr :value, :any
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""

  attr :rest, :global,
    include:
      ~w(autocomplete autocorrect autocapitalize spellcheck min max step pattern accept multiple)

  def input(assigns) do
    ~H"""
    <input
      type={@type}
      name={@name}
      id={@id}
      value={@value}
      placeholder={@placeholder}
      required={@required}
      disabled={@disabled}
      class={[
        "flex h-10 w-full rounded-md border border-gray-200 bg-white px-3 py-2 text-sm",
        "placeholder:text-gray-400",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-50",
        "file:border-0 file:bg-transparent file:text-sm file:font-medium",
        @class
      ]}
      {@rest}
    />
    """
  end
end
