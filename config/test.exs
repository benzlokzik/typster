import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :typster, Typster.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "typster_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :typster, TypsterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4002")],
  secret_key_base: "GMQ6J9YnE3SIkic1HR3dKRZ3/WYiR77kXh2/hO6BlLFVtFADZ6OlyUFVeInpTX+Q",
  server: false

# In test we don't send emails
config :typster, Typster.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :typster, Oban,
  testing: :manual,
  peer: false,
  plugins: false,
  queues: false,
  repo: Typster.Repo
