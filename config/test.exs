import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :shadowfax, Shadowfax.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "shadowfax_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :shadowfax, ShadowfaxWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "NTiU0P3r4hkkZP/peRD9CYFbdPMXCEAXDuFdC6ZHYCgSLKJbwDbHPPh1GQmyJOi6",
  server: false

# In test we don't send emails
config :shadowfax, Shadowfax.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Token configuration for testing
config :shadowfax,
  token_salt: "test_user_auth_token_salt",
  token_version: 1

# CORS configuration for testing
# Allow all origins in test environment
config :shadowfax, :cors,
  origins: ["http://localhost:4002"],
  max_age: 86400

# AWS/S3 configuration for testing
# Disable STS for tests - we don't want to hit AWS during tests
config :shadowfax,
  use_sts: false

config :ex_aws,
  access_key_id: "test_access_key",
  secret_access_key: "test_secret_key",
  region: "us-east-1"

config :ex_aws, :s3, bucket: "test-bucket"
