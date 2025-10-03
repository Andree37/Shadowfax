# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :shadowfax,
  ecto_repos: [Shadowfax.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :shadowfax, ShadowfaxWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ShadowfaxWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Shadowfax.PubSub,
  live_view: [signing_salt: "f8XIqcTr"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :shadowfax, Shadowfax.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Hammer rate limiting
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 2, cleanup_interval_ms: 60_000 * 10]}

# Configure AWS/S3 for file uploads
config :ex_aws,
  json_codec: Jason,
  region: System.get_env("AWS_REGION") || "us-east-1"

config :ex_aws, :s3, bucket: System.get_env("S3_BUCKET_NAME")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
