defmodule TypsterWeb.RestoreLocale do
  @moduledoc """
  LiveView `on_mount` hook that restores the Gettext locale from the session.

  The `:set_locale` router plug only runs on regular HTTP requests, so the
  dead (disconnected) render is localized correctly. LiveViews then connect
  over a WebSocket where the plug never runs; without this hook the connected
  re-render falls back to the default locale, causing the chosen language to
  flash and revert. Running here puts the locale on the LiveView process for
  both the disconnected and connected mounts.
  """

  @default "en"

  def on_mount(:default, _params, session, socket) do
    locale = session["locale"]
    supported = TypsterWeb.LocaleController.supported()
    Gettext.put_locale(TypsterWeb.Gettext, if(locale in supported, do: locale, else: @default))
    {:cont, socket}
  end
end
