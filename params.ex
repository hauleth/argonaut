defmodule Argonaut.Params do
  def parse(data, type) do
    data
    |> extract
    |> check(type)
  end

  def parse!(data, type) do
    case parse(data, type) do
      {:ok, attributes} -> attributes
      {:error, message} -> raise Argonaut.InvalidData, message: message
    end
  end

  defp extract(%{"data" => data}), do: {:ok, data}
  defp extract(_), do: {:error, "Missing data"}

  defp check({:ok, data}, type) do
    case data do
      %{"type" => ^type, "attributes" => attributes} -> {:ok, attributes}
      %{"type" => other} -> {:error, "Expected #{type} got #{other}"}
      _ -> {:error, "Unknown type, expected #{type}"}
    end
  end
  defp check({:error, _} = error, _), do: error
end

defmodule Argonaut.InvalidData do
  defexception message: "Invalid data", plug_status: 422

  def message(%__MODULE__{message: message}), do: message
end
