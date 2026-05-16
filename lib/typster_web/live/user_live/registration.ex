defmodule TypsterWeb.UserLive.Registration do
  use TypsterWeb, :live_view

  alias Typster.Accounts
  alias Typster.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash} current_scope={@current_scope}>
      <h1>{gettext("registration.title_prefix")} <em>Typster</em></h1>
      <p class="auth-subtitle">
        {gettext("registration.have_account")}
        <.link navigate={~p"/users/log-in"}>{gettext("auth.log_in")}</.link>
      </p>

      <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
        <.input
          field={@form[:email]}
          type="email"
          label={gettext("common.email")}
          autocomplete="username"
          required
          class="auth-input"
          error_class="auth-input auth-input--error"
          phx-mounted={JS.focus()}
        />
        <button
          type="submit"
          class="mk-btn mk-btn-primary"
          phx-disable-with={gettext("registration.creating")}
        >
          {gettext("registration.create_account")}
        </button>
      </.form>
    </Layouts.auth>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: TypsterWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext(
             "registration.flash.instructions_sent",
             email: user.email
           )
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
