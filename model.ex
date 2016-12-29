defmodule Argonaut.Model do
  import Ecto.Changeset

  def set_assoc(changeset, name, %{"id" => id}) do
    put_change(changeset, :"#{name}_id", id)
  end
  def set_assoc(changeset, name, %{id: id}) do
    put_change(changeset, :"#{name}_id", id)
  end
  def set_assoc(changeset, _, nil), do: changeset
end
