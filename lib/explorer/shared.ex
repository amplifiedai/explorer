defmodule Explorer.Shared do
  # A collection of **private** helpers shared in Explorer.
  @moduledoc false

  @doc """
  All supported dtypes.
  """
  def dtypes,
    do: [
      :binary,
      :boolean,
      :category,
      :date,
      :time,
      {:datetime, :nanosecond},
      {:datetime, :microsecond},
      {:datetime, :millisecond},
      :float,
      :integer,
      :string
    ]

  @doc """
  Supported datetime dtypes.
  """
  def datetime_types,
    do: [{:datetime, :nanosecond}, {:datetime, :microsecond}, {:datetime, :millisecond}]

  @doc """
  Gets the backend from a `Keyword.t()` or `nil`.
  """
  def backend_from_options!(opts) do
    case Keyword.fetch(opts, :backend) do
      {:ok, backend} when is_atom(backend) ->
        backend

      {:ok, other} ->
        raise ArgumentError,
              ":backend must be an atom, got: #{inspect(other)}"

      :error ->
        nil
    end
  end

  @doc """
  Normalize column names and raise if column does not exist.
  """
  def to_existing_columns(df, columns) when is_list(columns) do
    {columns, _cache} =
      Enum.map_reduce(columns, nil, fn
        column, maybe_map when is_integer(column) ->
          map = maybe_map || column_index_map(df.names)
          existing_column = fetch_column_at!(map, column)
          {existing_column, map}

        column, maybe_map when is_atom(column) ->
          column = Atom.to_string(column)
          maybe_raise_column_not_found(df, column)
          {column, maybe_map}

        column, maybe_map when is_binary(column) ->
          maybe_raise_column_not_found(df, column)
          {column, maybe_map}
      end)

    columns
  end

  def to_existing_columns(%{names: names}, 0..-1//1) do
    names
  end

  def to_existing_columns(%{names: names}, %Range{} = columns) do
    Enum.slice(names, columns)
  end

  def to_existing_columns(%{names: names}, %Regex{} = columns) do
    Enum.filter(names, &Regex.match?(columns, &1))
  end

  def to_existing_columns(%{names: names}, callback) when is_function(callback, 1) do
    Enum.filter(names, callback)
  end

  def to_existing_columns(%{names: names, dtypes: dtypes}, callback)
      when is_function(callback, 2) do
    Enum.filter(names, fn name -> callback.(name, dtypes[name]) end)
  end

  def to_existing_columns(_, other) do
    raise ArgumentError, """
    invalid columns specification. Columns may be specified as one of:

      * a list of columns indexes or names as atoms and strings

      * a range

      * a regex that keeps only the names matching the regex

      * a one-arity function that receives column names and returns
        true for column names to keep

      * a two-arity function that receives column names and types and
        returns true for column names to keep

    Got: #{inspect(other)}
    """
  end

  defp fetch_column_at!(map, index) do
    normalized = if index < 0, do: index + map_size(map), else: index

    case map do
      %{^normalized => column} -> column
      %{} -> raise ArgumentError, "no column exists at index #{index}"
    end
  end

  defp column_index_map(names),
    do: for({name, idx} <- Enum.with_index(names), into: %{}, do: {idx, name})

  @doc """
  Raises if a column is not found.
  """
  def maybe_raise_column_not_found(df, name) do
    unless Map.has_key?(df.dtypes, name) do
      raise ArgumentError,
            List.to_string([
              "could not find column name \"#{name}\"" | did_you_mean(name, df.names)
            ])
    end
  end

  @doc """
  Applies a function with args using the implementation of a dataframe or series.
  """
  def apply_impl(df_or_series_or_list, fun, args \\ []) do
    impl = impl!(df_or_series_or_list)
    apply(impl, fun, [df_or_series_or_list | args])
  end

  defp impl!(%{data: %struct{}}), do: struct

  defp impl!([%{data: %first_struct{}} | _] = dfs) when is_list(dfs),
    do: Enum.reduce(dfs, first_struct, fn %{data: %struct{}}, acc -> pick_impl(acc, struct) end)

  defp pick_impl(struct, struct), do: struct

  defp pick_impl(struct1, struct2) do
    raise "cannot invoke Explorer function because it relies on two incompatible implementations: " <>
            "#{inspect(struct1)} and #{inspect(struct2)}"
  end

  @doc """
  Gets the `dtype` of a list or raise error if not possible.

  It's possible to override the initial type by passing a preferable type.
  This is useful in cases where you want to build the series in a target type,
  without the need to cast it later.
  """
  def check_types!(list, preferable_type \\ nil) do
    initial_type =
      if preferable_type in [:binary, :float, :integer, :category], do: preferable_type

    type =
      Enum.reduce(list, initial_type, fn el, type ->
        new_type = type(el, type) || type

        cond do
          new_type == :numeric and type in [:float, :integer] ->
            new_type

          new_type != type and type != nil ->
            raise ArgumentError,
                  "the value #{inspect(el)} does not match the inferred series dtype #{inspect(type)}"

          true ->
            new_type
        end
      end)

    type || preferable_type || :float
  end

  defp type(item, type) when is_integer(item) and type == :float, do: :numeric
  defp type(item, type) when is_float(item) and type == :integer, do: :numeric
  defp type(item, type) when is_number(item) and type == :numeric, do: :numeric

  defp type(item, type)
       when item in [:nan, :infinity, :neg_infinity] and type in [:integer, :float, :numeric],
       do: :numeric

  defp type(item, _type) when is_integer(item), do: :integer
  defp type(item, _type) when is_float(item), do: :float
  defp type(item, _type) when item in [:nan, :infinity, :neg_infinity], do: :float
  defp type(item, _type) when is_boolean(item), do: :boolean

  defp type(item, :binary) when is_binary(item), do: :binary
  defp type(item, :category) when is_binary(item), do: :category
  defp type(item, _type) when is_binary(item), do: :string

  defp type(%Date{} = _item, _type), do: :date
  defp type(%Time{} = _item, _type), do: :time
  defp type(%NaiveDateTime{} = _item, _type), do: {:datetime, :microsecond}
  defp type(item, _type) when is_nil(item), do: nil
  defp type(item, _type), do: raise(ArgumentError, "unsupported datatype: #{inspect(item)}")

  @doc """
  Downcasts lists of mixed numeric types (float and int) to float.
  """
  def cast_numerics(list, type) when type == :numeric do
    data =
      Enum.map(list, fn
        item when item in [nil, :infinity, :neg_infinity, :nan] -> item
        item -> item / 1
      end)

    {data, :float}
  end

  def cast_numerics(list, type), do: {list, type}

  @doc """
  Helper for shared behaviour in inspect.
  """
  def to_string(nil, _opts), do: "nil"
  def to_string(:nan, _opts), do: "NaN"
  def to_string(:infinity, _opts), do: "Inf"
  def to_string(:neg_infinity, _opts), do: "-Inf"
  def to_string(i, _opts) when is_binary(i), do: inspect(i)
  def to_string(i, _opts), do: Kernel.to_string(i)

  @doc """
  Converts a dtype to a binary type when possible.
  """
  def dtype_to_iotype!(dtype) do
    case dtype do
      :float -> {:f, 64}
      :integer -> {:s, 64}
      :boolean -> {:u, 8}
      :date -> {:s, 32}
      :time -> {:s, 64}
      {:datetime, _} -> {:s, 64}
      _ -> raise ArgumentError, "cannot convert dtype #{dtype} into a binary/tensor type"
    end
  end

  @doc """
  Converts a binary type to dtype.
  """
  def iotype_to_dtype!(type) do
    case type do
      {:f, 64} -> :float
      {:s, 64} -> :integer
      {:u, 8} -> :boolean
      {:s, 32} -> :date
      _ -> raise ArgumentError, "cannot convert binary/tensor type #{inspect(type)} into dtype"
    end
  end

  @doc """
  Converts dtype to its string representation.
  """
  def dtype_to_string({:datetime, :millisecond}), do: "datetime[ms]"
  def dtype_to_string({:datetime, :microsecond}), do: "datetime[μs]"
  def dtype_to_string({:datetime, :nanosecond}), do: "datetime[ns]"
  def dtype_to_string(other), do: Atom.to_string(other)

  @threshold 0.77
  @max_suggestions 5

  @doc """
  Provides did_you_mean suggestions based on keys.
  """
  def did_you_mean(missing_key, available_keys) do
    suggestions =
      for key <- available_keys,
          distance = String.jaro_distance(missing_key, key),
          distance >= @threshold,
          do: {distance, key}

    case suggestions do
      [] -> [". The available entries are: #{inspect(available_keys)}"]
      suggestions -> [". Did you mean:\n\n" | format_suggestions(suggestions)]
    end
  end

  defp format_suggestions(suggestions) do
    suggestions
    |> Enum.sort(&(elem(&1, 0) >= elem(&2, 0)))
    |> Enum.take(@max_suggestions)
    |> Enum.sort(&(elem(&1, 1) <= elem(&2, 1)))
    |> Enum.map(fn {_, key} -> ["      * ", inspect(key), ?\n] end)
  end
end
