defmodule ShadowfaxWeb.Plugs.RateLimitMessages do
  @moduledoc """
  Rate limiting for message creation endpoints.
  Prevents message spam.
  """
  alias ShadowfaxWeb.Plugs.RateLimit

  def init(_opts) do
    RateLimit.init(
      limit: 30,
      period: 60_000,
      id_fn: &message_id/1
    )
  end

  def call(conn, opts) do
    RateLimit.call(conn, opts)
  end

  defp message_id(conn) do
    # Use user_id if authenticated, otherwise fall back to IP
    case conn.assigns[:current_user] do
      %{id: user_id} ->
        "messages:user:#{user_id}"

      _ ->
        ip =
          conn.remote_ip
          |> Tuple.to_list()
          |> Enum.join(".")

        "messages:ip:#{ip}"
    end
  end
end
