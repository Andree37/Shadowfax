defmodule HelloSocketsWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel("ping", HelloSocketsWeb.PingChannel)
  channel("wild:*", HelloSocketsWeb.WildcardChannel)

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
