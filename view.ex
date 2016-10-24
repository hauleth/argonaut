defmodule Argonaut.View do
  @moduledoc """
  Simplify JSON API views
  """

  defmacro __using__(name) when is_atom(name) or is_bitstring(name) do
    views(singular: name)
  end
  defmacro __using__(opts) when is_list(opts) do
    views(opts)
  end

  defp views(opts) do
    singular = opts[:singular]
    plural = opts[:plural] || :"#{singular}s"

    quote do
      def render("index.json", %{unquote(plural) => items} = map) do
        %{
          data: render_many(items, __MODULE__, "#{unquote(singular)}.json"),
          meta: map[:meta] || %{},
        }
      end
      def render("show.json", %{unquote(singular) => item} = map) do
        %{
          data: render_one(item, __MODULE__, "#{unquote(singular)}.json"),
          meta: map[:meta] || %{},
        }
      end
    end
  end
end
