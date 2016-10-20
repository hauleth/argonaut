defmodule Argonaut.Plug do
  import Plug.Conn

  @moduledoc """
  Plug that reject queries with invalid `Content-Type` header
  """

  @content_type "application/vnd.api+json"

  def init(options), do: options

  def call(conn, _opts) do
    if jsonapi?(conn) do
      conn
      |> put_resp_content_type(@content_type)
    else
      conn
      |> send_resp(:unsupported_media_type, "")
      |> halt
    end
  end

  def jsonapi?(conn) do
    get_req_header(conn, "content-type") == [@content_type]
  end
end
