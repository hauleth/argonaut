defmodule Argonaut.Model do
  import Ecto.Changeset
  import Ecto.Query

  defmacro set_assoc(changeset, name, value) do
    quote do
      Argonaut.Model.add(unquote(changeset),
                         __MODULE__.__schema__(:association, unquote(name)),
                         unquote(value))
    end
  end

  def add(changeset, _, nil), do: changeset
  def add(changeset, %Ecto.Association.ManyToMany{field: field, related: model}, values) when is_list(values) do
    entries = Enum.map(values, &struct(model, %{id: extract(&1)}))

    put_assoc(changeset, field, entries)
  end
  def add(changeset, %Ecto.Association.BelongsTo{owner_key: field} = assoc, value) do
    put_change(changeset, field, extract(value))
  end

  defp extract(%{id: id}), do: id
  defp extract(%{"id" => id}), do: id
end
