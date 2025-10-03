defmodule ShadowfaxWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug using Hammer to prevent spam and abuse.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts) do
    %{
      limit: Keyword.get(opts, :limit, 10),
      period: Keyword.get(opts, :period, 60_000),
      id_fn: Keyword.get(opts, :id_fn, &default_id/1)
    }
  end

  def call(conn, opts) do
    id = opts.id_fn.(conn)
    bucket_name = "rate_limit:#{id}"

    case Hammer.check_rate(bucket_name, opts.period, opts.limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          success: false,
          error: "Rate limit exceeded. Please try again later."
        })
        |> halt()
    end
  end

  defp default_id(conn) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end
end
