defmodule Argonaut.View do
  @moduledoc """
  Simplify JSON API views
  """

  defmacro __using__(_) do
    quote do
      import Argonaut.View, only: [schema: 2]
      @primary_key nil

      Module.register_attribute(__MODULE__, :argonaut_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :argonaut_relations, accumulate: true)
    end
  end

  defmacro schema(type, [do: block]) do
    views(type, block)
  end

  defmacro field(name, opts \\ []) do
    quote do
      Argonaut.View.__field__(__MODULE__, unquote(name), unquote(opts))
    end
  end

  defmacro has_one(name, view, opts \\ []) do
    quote do
      Argonaut.View.__relation__(__MODULE__, :one, unquote(name), unquote(view), unquote(opts))
    end
  end

  defmacro has_many(name, view, opts \\ []) do
    quote do
      Argonaut.View.__relation__(__MODULE__, :many, unquote(name), unquote(view), unquote(opts))
    end
  end

  defp views(type, block) do
    quote do
      require Argonaut.View

      if @primary_key == nil do
        @primary_key :id
      end

      try do
        import Argonaut.View
        unquote(block)
      after
        :ok
      end

      def __type__ do
        "#{unquote(type)}"
      end

      def render("index.json", %{data: items} = extra) do
        Argonaut.View.__render__(items, __MODULE__, extra)
      end
      def render("show.json", %{data: item} = extra) do
        Argonaut.View.__render__(item, __MODULE__, extra)
      end
      def render("item.json", %{item: item} = map) do
        %{id: Map.fetch!(item, @primary_key),
          type: __type__,
          attributes: Argonaut.View.__attributes__(__MODULE__, item, @argonaut_fields),
          relationships: Argonaut.View.__relations__(__MODULE__, item, @argonaut_relations)}
      end
    end
  end

  def __field__(mod, name, opts) do
    Module.put_attribute(mod, :argonaut_fields, {name, opts})
  end

  def __relation__(mod, count, name, view, opts) do
    Module.put_attribute(mod, :argonaut_fields, {name, opts ++ [relation: count, type: opts[:type] || view.__type__]})
    Module.put_attribute(mod, :argonaut_relations, {name, count, view, opts})
  end

  def __attributes__(mod, model, fields) do
    Enum.reduce(fields, %{}, fn({field, opts}, acc) ->
      id = opts[:as] || field
      alternative = opts[:or]
      value = cond do
        opts[:value] -> opts[:value]
        :erlang.function_exported(mod, field, 1) -> apply(mod, field, [model])
        opts[:relation] == :one -> %{id: Map.fetch!(model, :"#{field}_id"), type: opts[:type]}
        opts[:relation] == :many ->
          Map.fetch!(model, field)
          |> Enum.map(&(%{id: &1.id, type: opts[:type]}))
        true -> Map.fetch!(model, field)
      end

      Map.put_new(acc, id, if value == nil do alternative else value end)
    end)
  end

  def __relations__(_mod, model, relations) do
    Enum.reduce(relations, [], fn({field, count, view, _opts}, acc) ->
      rel(acc, view, Map.fetch!(model, field))
    end)
  end

  defp rel(list, _view, %Ecto.Association.NotLoaded{}), do: list
  defp rel(list, view, models) when is_list(models) do
    list ++ Enum.map(models, &Phoenix.View.render(view, "item.json", item: &1))
  end
  defp rel(list, view, model) do
    list ++ [Phoenix.View.render(view, "item.json", item: model)]
  end

  def __render__(data, module, extra) when is_list(data) do
    %{data: Phoenix.View.render_many(data, module, "item.json", as: :item)}
    |> meta(extra[:meta])
  end
  def __render__(data, module, extra) do
    %{data: Phoenix.View.render_one(data, module, "item.json", as: :item)}
    |> meta(extra[:meta])
  end

  defp meta(data, nil), do: data
  defp meta(data, extra) do
    Map.put(data, :meta, extra)
  end
end
