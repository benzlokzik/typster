defmodule TypsterWeb.Router do
  use TypsterWeb, :router

  import TypsterWeb.UserAuth

  defp set_locale(conn, _opts) do
    locale = get_session(conn, :locale) || "en"
    Gettext.put_locale(TypsterWeb.Gettext, locale)
    conn
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TypsterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :set_locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :fetch_current_scope_for_api
    plug :require_authenticated_api_user
  end

  scope "/", TypsterWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/locale/:locale", LocaleController, :set
  end

  scope "/", TypsterWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      on_mount: [{TypsterWeb.UserAuth, :require_authenticated}] do
      live "/projects", ProjectLive.Index
      live "/projects/:id", ProjectLive.Show
      live "/projects/:id/edit", EditorLive.Index
    end
  end

  scope "/api", TypsterWeb.Api, as: :api do
    pipe_through :api

    get "/health", HealthController, :show
    post "/users/log-in", SessionController, :create
  end

  scope "/api", TypsterWeb.Api, as: :api do
    pipe_through [:api, :api_auth]

    delete "/users/log-out", SessionController, :delete

    resources "/projects", ProjectController, except: [:new, :edit] do
      resources "/files", FileController, only: [:index, :create, :update, :delete]
    end
  end

  if Application.compile_env(:typster, :e2e_auth_routes, false) do
    scope "/dev", TypsterWeb do
      pipe_through :browser

      post "/test-login", E2EAuthController, :create
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:typster, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TypsterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TypsterWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TypsterWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", TypsterWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TypsterWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
