defmodule TypsterWeb.UserLive.Settings do
  use TypsterWeb, :live_view

  on_mount {TypsterWeb.UserAuth, :require_sudo_mode}

  alias Typster.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main class="ts-main">
        <div class="ts-page ts-page--narrow">
          <header class="ts-pagehead">
            <div>
              <h1 class="ts-h1">{gettext("settings.title")}</h1>
              <p class="ts-p ts-muted">
                {gettext("settings.subtitle")}
              </p>
            </div>
          </header>

          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
          >
            <section class="ts-card">
              <div class="ts-card__h">
                <h3 class="ts-h3">{gettext("common.email")}</h3>
                <p class="ts-p ts-muted">{gettext("settings.email.description")}</p>
              </div>
              <div class="ts-card__c">
                <label class="ts-field">
                  <span class="ts-field__label">{gettext("common.email")}</span>
                  <.input
                    field={@email_form[:email]}
                    type="email"
                    class="ts-input"
                    autocomplete="username"
                    required
                  />
                </label>
              </div>
              <div class="ts-card__f">
                <button
                  type="submit"
                  class="ts-btn ts-btn--primary"
                  phx-disable-with={gettext("settings.email.changing")}
                >
                  {gettext("settings.email.change")}
                </button>
              </div>
            </section>
          </.form>

          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              autocomplete="username"
              value={@current_email}
            />
            <section class="ts-card">
              <div class="ts-card__h">
                <h3 class="ts-h3">{gettext("common.password")}</h3>
                <p class="ts-p ts-muted">
                  {gettext("settings.password.description")}
                </p>
              </div>
              <div class="ts-card__c">
                <label class="ts-field">
                  <span class="ts-field__label">{gettext("settings.password.new_label")}</span>
                  <.input
                    field={@password_form[:password]}
                    type="password"
                    class="ts-input"
                    autocomplete="new-password"
                    required
                  />
                </label>
                <label class="ts-field">
                  <span class="ts-field__label">{gettext("settings.password.confirm_label")}</span>
                  <.input
                    field={@password_form[:password_confirmation]}
                    type="password"
                    class="ts-input"
                    autocomplete="new-password"
                  />
                </label>
              </div>
              <div class="ts-card__f">
                <button
                  type="submit"
                  class="ts-btn ts-btn--primary"
                  phx-disable-with={gettext("common.saving")}
                >
                  {gettext("settings.password.save")}
                </button>
              </div>
            </section>
          </.form>

          <section class="ts-card ts-card--danger">
            <div class="ts-card__h">
              <h3 class="ts-h3">{gettext("settings.danger.title")}</h3>
              <p class="ts-p ts-muted">
                {gettext("settings.danger.description")}
              </p>
            </div>
            <div class="ts-card__f">
              <button class="ts-btn ts-btn--destructive" disabled>
                {gettext("settings.danger.delete_account")}
              </button>
            </div>
          </section>
        </div>
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, gettext("settings.flash.email_changed"))

        {:error, _} ->
          put_flash(socket, :error, gettext("settings.flash.email_change_invalid"))
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = gettext("settings.flash.email_change_sent")
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
