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

  defmacro schema(typ, [do: block]) do
    views(typ, block)
  end

  defmacro field(name, opts \\ []) do
    quote do
      Argonaut.View.__field__(__MODULE__, unquote(name), unquote(opts))
    end
  end

  defmacro has(name, view, opts \\ []), do: __has__(name, view, opts)

  defp __has__(name, opts, _) when is_list(opts), do: __has__(name, nil, opts)
  defp __has__(name, view, opts) do
    quote do
      Argonaut.View.__relation__(__MODULE__, unquote(name), unquote(view), unquote(opts))
    end
  end

  defp views(typ, block) do
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

      def type do
        "#{unquote(typ)}"
      end

      @spec render(charlist, map) :: map
      def render("index.json", %{data: items} = extra) do
        Argonaut.View.__render__(items, __MODULE__, extra)
      end
      def render("show.json", %{data: item} = extra) do
        Argonaut.View.__render__(item, __MODULE__, extra)
      end
      def render("item.json", %{item: item} = map) do
        id = Argonaut.View.__id__(item, @primary_key)
        attributes = Argonaut.View.__attributes__(__MODULE__, item, @argonaut_fields)
        relationships = Argonaut.View.__relations__(__MODULE__, item, @argonaut_relations)

        %{id: id,
          type: type(),
          attributes: attributes,
          relationships: relationships}
      end
    end
  end

  def __id__(model, [id]), do: Map.fetch!(model, id)
  def __id__(model, [field | rest]), do: __id__(Map.fetch!(model, field), rest)
  def __id__(model, id), do: Map.fetch!(model, id)

  def __field__(mod, name, opts) do
    Module.put_attribute(mod, :argonaut_fields, {name, opts})
  end

  def __relation__(mod, name, view, [{:skip, true} | _] = opts) do
    Module.put_attribute(mod, :argonaut_relations, {name, view, opts})
  end
  def __relation__(mod, name, view, opts) do
    Module.put_attribute(mod, :argonaut_relations, {name, view, opts})
  end

  def __attributes__(mod, model, fields) do
    Enum.reduce(fields, %{}, fn({field, opts}, acc) ->
      name = opts[:as] || field
      model = if opts[:delegate] do
        Map.fetch!(model, opts[:delegate])
      else
        model
      end
      value = value(mod, model, field, opts)

      Map.put_new(acc, name, value)
    end)
  end

  defp value(mod, model, field, [{:submodel, true} | rest]) do
    case value(mod, model, field, rest) do
      %Ecto.Association.NotLoaded{} -> Keyword.get(rest, :or)
      nil -> Keyword.get(rest, :or)
      val -> val
    end
  end
  defp value(_mod, _model, _field, [{:value, value} | _]), do: value
  defp value(mod, model, field, [{:relation, true}, {:type, type} | _]) do
    entries = relation(mod, model, field)

    encode_relation(entries, type)
  end
  defp value(mod, model, field, _opts) do
    if :erlang.function_exported(mod, field, 1) do
      apply(mod, field, [model])
    else
      Map.fetch!(model, field)
    end
  end

  defp encode_relation(nil, _), do: nil
  defp encode_relation(%Ecto.Association.NotLoaded{}, _), do: nil
  defp encode_relation(entries, typ) when is_list(entries) do
    entries
    |> Enum.map(&encode_relation(&1, typ))
  end
  defp encode_relation(%{id: id}, typ), do: %{id: id, type: typ}

  def __relations__(mod, model, relations) do
    relations
    |> Enum.reduce([], fn({field, view, opts}, acc) ->
      rel(acc, view, relation(mod, model, field), opts)
    end)
    |> Enum.filter(&(&1))
  end

  defp relation(mod, model, field) do
    if :erlang.function_exported(mod, field, 1) do
      apply(mod, field, [model])
    else
      Map.fetch!(model, field)
    end
  end

  defp rel(list, _view, nil, _opts), do: list
  defp rel(list, _view, %Ecto.Association.NotLoaded{}, [{:allow_not_loaded, true} | _]), do: list
  defp rel(_list, _view, %Ecto.Association.NotLoaded{__field__: field}, _) do
    raise "Assoctiation #{field} not loaded, preload it or add `allow_not_loaded: true`"
  end
  defp rel(list, nil, models, _opts) when is_list(models), do: models ++ list
  defp rel(list, nil, model, _opts), do: [model | list]
  defp rel(list, view, models, _opts) when is_list(models) do
    Enum.map(models, &Phoenix.View.render(view, "item.json", item: &1)) ++ list
  end
  defp rel(list, view, model, _opts) do
    [Phoenix.View.render(view, "item.json", item: model) | list]
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
