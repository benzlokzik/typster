defmodule Typster.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TwMerge.Cache,
      TypsterWeb.Telemetry,
      Typster.Repo,
      {DNSCluster, query: Application.get_env(:typster, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Typster.PubSub},
      {Oban, Application.get_env(:typster, Oban)},
      # Start to serve requests, typically the last entry
      TypsterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Typster.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TypsterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
