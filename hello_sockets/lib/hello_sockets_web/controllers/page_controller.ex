defmodule HelloSocketsWeb.PageController do
  use HelloSocketsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
