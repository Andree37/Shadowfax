defmodule HelloSocketsWeb.PingChannel do
  use Phoenix.Channel

  def join("ping:" <> _subtopic, _message, socket) do
    {:ok, socket}
  end

  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{ping: "pong"}}, socket}
  end
end
