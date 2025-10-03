defmodule Shadowfax.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Conditionally start STS credential provider if configured
    sts_child =
      if Application.get_env(:shadowfax, :use_sts, false) do
        [{Shadowfax.AWS.STSCredentials, []}]
      else
        []
      end

    children =
      [
        ShadowfaxWeb.Telemetry,
        Shadowfax.Repo,
        {DNSCluster, query: Application.get_env(:shadowfax, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Shadowfax.PubSub},
        ShadowfaxWeb.Presence
        # Start a worker by calling: Shadowfax.Worker.start_link(arg)
        # {Shadowfax.Worker, arg},
      ] ++
        sts_child ++
        [
          # Start to serve requests, typically the last entry
          ShadowfaxWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Shadowfax.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShadowfaxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
