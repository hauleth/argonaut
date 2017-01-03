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

      def render("index.json", %{data: items} = extra) do
        Argonaut.View.__render__(items, __MODULE__, extra)
      end
      def render("show.json", %{data: item} = extra) do
        Argonaut.View.__render__(item, __MODULE__, extra)
      end
      def render("item.json", %{item: item} = map) do
        %{id: Map.fetch!(item, @primary_key),
          type: type,
          attributes: Argonaut.View.__attributes__(__MODULE__, item, @argonaut_fields),
          relationships: Argonaut.View.__relations__(__MODULE__, item, @argonaut_relations)}
      end
    end
  end

  def __field__(mod, name, opts) do
    Module.put_attribute(mod, :argonaut_fields, {name, opts})
  end

  def __relation__(mod, name, view, opts) do
    if !opts[:skip_field] do
      Module.put_attribute(mod, :argonaut_fields, {name, opts ++ [relation: true, type: opts[:type] || view.type]})
    end
    Module.put_attribute(mod, :argonaut_relations, {name, view, opts})
  end

  def __attributes__(mod, model, fields) do
    Enum.reduce(fields, %{}, fn({field, opts}, acc) ->
      id = opts[:as] || field
      alternative = opts[:or]
      model = if opts[:delegate] do
        Map.fetch!(model, opts[:delegate])
      else
        model
      end
      value = value(mod, model, field, opts)

      Map.put_new(acc, id, if value == nil do alternative else value end)
    end)
  end

  defp value(_mod, _model, _field, [{:value, value} | _]), do: value
  defp value(mod, model, field, [{:relation, true}, {:type, type} | _]) do
    entries = relation(mod, model, field)

    cond do
      is_list(entries) ->
        entries
        |> Enum.map(fn
                      %{id: id} -> %{id: id, type: type}
                      nil -> nil
        end)
      is_nil(entries) -> nil
      true -> %{id: entries.id, type: type}
    end
  end
  defp value(mod, model, field, _opts) do
    if :erlang.function_exported(mod, field, 1) do
      apply(mod, field, [model])
    else
      Map.fetch!(model, field)
    end
  end

  def __relations__(mod, model, relations) do
    relations
    |> Enum.reduce([], fn({field, view, _opts}, acc) ->
      rel(acc, view, relation(mod, model, field))
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

  defp rel(list, _view, nil), do: list
  defp rel(list, _view, %Ecto.Association.NotLoaded{}), do: list
  defp rel(list, nil, models) when is_list(models), do: list ++ models
  defp rel(list, nil, model), do: list ++ [model]
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
