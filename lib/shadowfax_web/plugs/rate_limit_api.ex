defmodule ShadowfaxWeb.Plugs.RateLimitAPI do
  @moduledoc """
  General API rate limiting.
  Prevents excessive API usage.
  """
  alias ShadowfaxWeb.Plugs.RateLimit

  def init(_opts) do
    RateLimit.init(
      limit: 100,
      period: 60_000,
      id_fn: &api_id/1
    )
  end

  def call(conn, opts) do
    RateLimit.call(conn, opts)
  end

  defp api_id(conn) do
    # Use user_id if authenticated, otherwise fall back to IP
    case conn.assigns[:current_user] do
      %{id: user_id} ->
        "api:user:#{user_id}"

      _ ->
        ip =
          conn.remote_ip
          |> Tuple.to_list()
          |> Enum.join(".")

        "api:ip:#{ip}"
    end
  end
end
