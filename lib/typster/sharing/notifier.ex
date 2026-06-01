defmodule Typster.Sharing.Notifier do
  @moduledoc """
  Outbound email notifications for project sharing and collaboration invites.
  """

  import Swoosh.Email

  alias Typster.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Typster", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver a collaboration invite to the given email for the named project.

  The `url` is a placeholder link the invitee can follow to accept.
  """
  def deliver_collaborator_invite(email, project_name, url) do
    deliver(email, "You've been invited to collaborate on #{project_name}", """

    ==============================

    Hi #{email},

    You've been invited to collaborate on the project "#{project_name}".

    Accept the invitation by visiting the URL below:

    #{url}

    If you weren't expecting this invitation, please ignore this email.

    ==============================
    """)
  end
end
