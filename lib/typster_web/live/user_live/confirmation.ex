defmodule TypsterWeb.UserLive.Confirmation do
  use TypsterWeb, :live_view

  alias Typster.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash} current_scope={@current_scope}>
      <h1>Welcome back</h1>
      <p class="auth-subtitle">{@user.email}</p>

      <.form
        :if={!@user.confirmed_at}
        for={@form}
        id="confirmation_form"
        phx-mounted={JS.focus_first()}
        phx-submit="submit"
        action={~p"/users/log-in?_action=confirmed"}
        phx-trigger-action={@trigger_submit}
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <button
          type="submit"
          name={@form[:remember_me].name}
          value="true"
          phx-disable-with="Confirming…"
          class="mk-btn mk-btn-primary"
        >
          Confirm and stay logged in
        </button>
        <button
          type="submit"
          phx-disable-with="Confirming…"
          class="mk-btn mk-btn-outline"
        >
          Confirm once
        </button>
      </.form>

      <.form
        :if={@user.confirmed_at}
        for={@form}
        id="login_form"
        phx-submit="submit"
        phx-mounted={JS.focus_first()}
        action={~p"/users/log-in"}
        phx-trigger-action={@trigger_submit}
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <%= if @current_scope do %>
          <button type="submit" phx-disable-with="Logging in…" class="mk-btn mk-btn-primary">
            Log in
          </button>
        <% else %>
          <button
            type="submit"
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Logging in…"
            class="mk-btn mk-btn-primary"
          >
            Keep me logged in
          </button>
          <button
            type="submit"
            phx-disable-with="Logging in…"
            class="mk-btn mk-btn-outline"
          >
            Log in once
          </button>
        <% end %>
      </.form>

      <div :if={!@user.confirmed_at} class="mk-alert mk-alert-info">
        <span class="mk-alert-icon">
          <.icon name="hero-information-circle" class="size-4" />
        </span>
        <div class="mk-alert-body">
          Tip: once confirmed, you can enable password login in settings.
        </div>
      </div>
    </Layouts.auth>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
