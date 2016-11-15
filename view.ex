defmodule Argonaut.View do
  @moduledoc """
  Simplify JSON API views
  """

  defmacro __using__(name) when is_atom(name) or is_bitstring(name) do
    views(singular: name)
  end
  defmacro __using__(opts) when is_list(opts), do: views(opts)

  defp views(opts) do
    singular = opts[:singular]
    plural = opts[:plural] || :"#{singular}s"

    quote do
      require Argonaut.View

      @behaviour Argonaut.View

      def render("index.json", %{unquote(plural) => items, conn: conn} = extra) do
        Argonaut.View.render(conn, items, __MODULE__, extra)
      end
      def render("show.json", %{unquote(singular) => item, conn: conn} = extra) do
        Argonaut.View.render(conn, item, __MODULE__, extra)
      end

      def render("item.json", %{item: item} = map) do
        %{id: item.id,
          type: "#{unquote(singular)}",
          attributes: attributes(item)}
        |> add_relations(item, item.__struct__.__schema__(:associations))
      end

      defp add_relations(data, model, relationships) do
        Enum.reduce(relationships, data, fn (field, data) ->
          add_relation(data, field, Map.fetch!(model, field))
        end)
      end

      defp add_relation(data, field, %Ecto.Association.NotLoaded{}), do: data
      defp add_relation(data, field, model) do
        case relation(field, model) do
          :skip -> data
          rel -> Map.update(data, :relationships, %{field => rel}, &Map.put_new(&1, field, rel))
        end
      end

      def relation(_, _), do: :skip

      defoverridable relation: 2
    end
  end

  def render(conn, data, module, extra) when is_list(data) do
    %{links: apply(module, :links, [conn, data]),
      data: Phoenix.View.render_many(data, module, "item.json", as: :item)}
    |> meta(extra[:meta])
  end
  def render(conn, data, module, extra) do
    %{links: apply(module, :links, [conn, data]),
      data: Phoenix.View.render_one(data, module, "item.json", as: :item)}
    |> meta(extra[:meta])
  end

  def meta(data, nil), do: data
  def meta(data, %{} = extra) do
    Map.put(data, :meta, extra)
  end

  @callback attributes(map()) :: map()
  @callback relation(atom(), map()) :: map() | :skip
  @callback links(map(), map() | list()) :: map()
  @optional_callbacks relation: 2
end
