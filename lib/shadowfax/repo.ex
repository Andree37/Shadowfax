defmodule Shadowfax.Repo do
  use Ecto.Repo,
    otp_app: :shadowfax,
    adapter: Ecto.Adapters.Postgres
end
