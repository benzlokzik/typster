defmodule TypsterWeb.UserLive.Login do
  use TypsterWeb, :live_view

  alias Typster.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash} current_scope={@current_scope}>
      <h1>Log in to <em>Typster</em></h1>
      <p class="auth-subtitle">
        <%= if @current_scope do %>
          Reauthenticate to access sensitive account settings.
        <% else %>
          No account? <.link navigate={~p"/users/register"}>Sign up</.link>
        <% end %>
      </p>

      <div :if={local_mail_adapter?()} class="mk-alert mk-alert-info">
        <span class="mk-alert-icon">
          <.icon name="hero-information-circle" class="size-4" />
        </span>
        <div class="mk-alert-body">
          Local mail adapter is active.
          View sent emails in <.link href="/dev/mailbox">the mailbox</.link>.
        </div>
      </div>

      <.form
        :let={f}
        for={@form}
        id="login_form_magic"
        action={~p"/users/log-in"}
        phx-submit="submit_magic"
      >
        <.input
          readonly={!!@current_scope}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="email"
          required
          class="auth-input"
          error_class="auth-input auth-input--error"
          phx-mounted={JS.focus()}
        />
        <button type="submit" class="mk-btn mk-btn-primary">
          Email me a link <span aria-hidden="true">→</span>
        </button>
      </.form>

      <div class="auth-divider">or</div>

      <.form
        :let={f}
        for={@form}
        id="login_form_password"
        action={~p"/users/log-in"}
        phx-submit="submit_password"
        phx-trigger-action={@trigger_submit}
      >
        <.input
          readonly={!!@current_scope}
          field={f[:email]}
          type="email"
          label="Email"
          autocomplete="email"
          required
          class="auth-input"
          error_class="auth-input auth-input--error"
        />
        <.input
          field={@form[:password]}
          type="password"
          label="Password"
          autocomplete="current-password"
          class="auth-input"
          error_class="auth-input auth-input--error"
        />
        <button
          type="submit"
          class="mk-btn mk-btn-primary"
          name={@form[:remember_me].name}
          value="true"
        >
          Stay signed in
        </button>
        <button type="submit" class="mk-btn mk-btn-outline">
          This session only
        </button>
      </.form>
    </Layouts.auth>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:typster, Typster.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
