defmodule Argonaut.Paginate do
  import Ecto.Query, only: [where: 3, limit: 2]

  def since(query, params, column \\ :inserted_at)
  def since(query, %{"last" => last}, column, batch \\ 20) do
    query
    |> where([f], field(f, ^column) < ^last)
    |> limit(batch)
  end
  def since(query, _, _), do: query

  def pagination_header(conn, items, column \\ :inserted_at)
  def pagination_header(conn, [], _), do: conn
  def pagination_header(%Plug.Conn{} = conn, items, column) when is_list(items) do
    last = items
           |> List.last
           |> Map.get(column)

    Plug.Conn.put_resp_header(conn, "x-last", to_string(last))
  end
  def pagination_header(conn, _, _), do: conn
end
