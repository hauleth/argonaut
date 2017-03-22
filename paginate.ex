defmodule Argonaut.Paginate do
  require Ecto.Query

  def next(query, params, order \\ {:desc, :inserted_at}, batch \\ 20)
  def next(query, %{"last" => last}, order, batch) do
    next(query, %{"x-last" => last}, order, batch)
  end
  def next(query, %{"x-last" => last}, order, batch) do
    ordering = [order]

    query
    |> Ecto.Query.order_by(^ordering)
    |> where(order, last)
    |> Ecto.Query.limit(^batch)
  end
  def next(query, _, order, batch) do
    ordering = [order]

    query
    |> Ecto.Query.order_by(^ordering)
    |> Ecto.Query.limit(^batch)
  end

  def header(conn, items, column \\ :inserted_at)
  def header(conn, [], _), do: conn
  def header(%Plug.Conn{} = conn, items, column) when is_list(items) do
    last = items
           |> List.last
           |> Map.get(column)

    Plug.Conn.put_resp_header(conn, "x-last", to_string(last))
  end
  def header(conn, _, _), do: conn

  defp where(query, {:desc, column}, last) do
    Ecto.Query.where(query, [f], field(f, ^column) < ^last)
  end
  defp where(query, {:asc, column}, last) do
    Ecto.Query.where(query, [f], field(f, ^column) > ^last)
  end
end
