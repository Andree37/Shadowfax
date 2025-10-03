defmodule ShadowfaxWeb.Plugs.RateLimitAuth do
  @moduledoc """
  Rate limiting for authentication endpoints.
  Stricter limits to prevent brute force attacks.
  """
  alias ShadowfaxWeb.Plugs.RateLimit

  def init(_opts) do
    RateLimit.init(
      limit: 5,
      period: 60_000,
      id_fn: &auth_id/1
    )
  end

  def call(conn, opts) do
    RateLimit.call(conn, opts)
  end

  defp auth_id(conn) do
    ip =
      conn.remote_ip
      |> Tuple.to_list()
      |> Enum.join(".")

    "auth:#{ip}"
  end
end
