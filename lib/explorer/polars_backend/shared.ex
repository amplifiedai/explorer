defmodule Explorer.PolarsBackend.Shared do
  # A collection of **private** helpers shared in Explorer.PolarsBackend.
  @moduledoc false

  alias Explorer.DataFrame, as: DataFrame
  alias Explorer.PolarsBackend.DataFrame, as: PolarsDataFrame
  alias Explorer.PolarsBackend.LazyFrame, as: PolarsLazyFrame
  alias Explorer.PolarsBackend.Native
  alias Explorer.PolarsBackend.Series, as: PolarsSeries
  alias Explorer.Series, as: Series

  @polars_df [PolarsDataFrame, PolarsLazyFrame]

  def apply(fun, args \\ []) do
    case apply(Native, fun, args) do
      {:ok, value} -> value
      {:error, error} -> raise runtime_error(error)
    end
  end

  # Applies to a series. Expects a series or a value back.
  def apply_series(%Series{} = series, fun, args \\ []) do
    case apply(Native, fun, [series.data | args]) do
      {:ok, %PolarsSeries{} = new_series} -> create_series(new_series)
      {:ok, value} -> value
      {:error, error} -> raise runtime_error(error)
    end
  end

  # Applies to a dataframe. Expects a series or a value back.
  def apply_dataframe(%DataFrame{} = df, fun, args \\ []) do
    case apply(Native, fun, [df.data | args]) do
      {:ok, %PolarsSeries{} = new_series} -> create_series(new_series)
      {:ok, value} -> value
      {:error, error} -> raise runtime_error(error)
    end
  end

  @check_frames Application.compile_env(:explorer, :check_polars_frames, false)

  # Applies to a dataframe. Expects a dataframe back.
  def apply_dataframe(%DataFrame{} = df, %DataFrame{} = out_df, fun, args) do
    case apply(Native, fun, [df.data | args]) do
      {:ok, %module{} = new_df} when module in @polars_df ->
        if @check_frames do
          check_df = create_dataframe(new_df)

          if Enum.sort(out_df.names) != Enum.sort(check_df.names) or
               out_df.dtypes != check_df.dtypes do
            raise """
            DataFrame mismatch.

            expected:

                names: #{inspect(out_df.names)}
                dtypes: #{inspect(out_df.dtypes)}

            got:

                names: #{inspect(check_df.names)}
                dtypes: #{inspect(check_df.dtypes)}
            """
          end
        end

        %{out_df | data: new_df}

      {:error, error} ->
        raise runtime_error(error)
    end
  end

  def create_series(%PolarsSeries{} = polars_series) do
    dtype =
      case Native.s_dtype(polars_series) do
        {:ok, dtype} ->
          dtype

        {:error, reason} ->
          raise ArgumentError, reason
      end

    Explorer.Backend.Series.new(polars_series, dtype)
  end

  def create_dataframe(polars_df) do
    Explorer.Backend.DataFrame.new(polars_df, df_names(polars_df), df_dtypes(polars_df))
  end

  defp df_names(%PolarsDataFrame{} = polars_df) do
    {:ok, names} = Native.df_names(polars_df)
    names
  end

  defp df_names(%PolarsLazyFrame{} = polars_df) do
    {:ok, names} = Native.lf_names(polars_df)
    names
  end

  defp df_dtypes(%PolarsDataFrame{} = polars_df) do
    {:ok, dtypes} = Native.df_dtypes(polars_df)
    dtypes
  end

  defp df_dtypes(%PolarsLazyFrame{} = polars_df) do
    {:ok, dtypes} = Native.lf_dtypes(polars_df)
    dtypes
  end

  def from_list(list, dtype), do: from_list(list, dtype, "")

  def from_list(list, {:list, inner_dtype} = _dtype, name) when is_list(list) do
    series =
      Enum.map(list, fn maybe_inner_list ->
        if is_list(maybe_inner_list), do: from_list(maybe_inner_list, inner_dtype, name)
      end)

    Native.s_from_list_of_series(name, series)
  end

  def from_list(list, dtype, name) when is_list(list) do
    case dtype do
      :integer -> Native.s_from_list_i64(name, list)
      {:f, 32} -> Native.s_from_list_f32(name, list)
      {:f, 64} -> Native.s_from_list_f64(name, list)
      :boolean -> Native.s_from_list_bool(name, list)
      :string -> Native.s_from_list_str(name, list)
      :category -> Native.s_from_list_categories(name, list)
      :date -> Native.s_from_list_date(name, list)
      :time -> Native.s_from_list_time(name, list)
      {:datetime, precision} -> Native.s_from_list_datetime(name, list, Atom.to_string(precision))
      {:duration, precision} -> Native.s_from_list_duration(name, list, Atom.to_string(precision))
      :binary -> Native.s_from_list_binary(name, list)
    end
  end

  def from_binary(binary, dtype, name \\ "") when is_binary(binary) do
    case dtype do
      :boolean ->
        Native.s_from_binary_u8(name, binary) |> Native.s_cast(dtype) |> ok()

      :date ->
        Native.s_from_binary_i32(name, binary) |> Native.s_cast(dtype) |> ok()

      :time ->
        Native.s_from_binary_i64(name, binary) |> Native.s_cast(dtype) |> ok()

      {:datetime, :millisecond} ->
        Native.s_from_binary_i64(name, binary) |> Native.s_cast(dtype) |> ok()

      {:datetime, :microsecond} ->
        Native.s_from_binary_i64(name, binary) |> Native.s_cast(dtype) |> ok()

      {:datetime, :nanosecond} ->
        Native.s_from_binary_i64(name, binary) |> Native.s_cast(dtype) |> ok()

      {:duration, :millisecond} ->
        Native.s_from_binary_i64(name, binary) |> Native.s_cast(dtype) |> ok()

      {:duration, :microsecond} ->
        Native.s_from_binary_i64(name, binary) |> Native.s_cast(dtype) |> ok()

      {:duration, :nanosecond} ->
        Native.s_from_binary_i64(name, binary) |> Native.s_cast(dtype) |> ok()

      :integer ->
        Native.s_from_binary_i64(name, binary)

      {:f, 32} ->
        Native.s_from_binary_f32(name, binary)

      {:f, 64} ->
        Native.s_from_binary_f64(name, binary)
    end
  end

  defp ok({:ok, value}), do: value

  defp runtime_error(error) when is_binary(error), do: RuntimeError.exception(error)

  def parquet_compression(nil, _), do: :uncompressed

  def parquet_compression(algorithm, level) when algorithm in ~w(gzip brotli zstd)a,
    do: {algorithm, level}

  def parquet_compression(algorithm, _) when algorithm in ~w(snappy lz4raw)a, do: algorithm

  @doc """
  Builds and returns a path for a new file.

  It saves in a directory called "elixir-explorer-datasets" inside
  the `System.tmp_dir()`.
  """
  def build_path_for_entry(%FSS.S3.Entry{} = entry) do
    bucket = entry.config.bucket || "default-explorer-bucket"

    hash =
      :crypto.hash(:sha256, entry.config.endpoint <> "/" <> bucket <> "/" <> entry.key)
      |> Base.url_encode64(padding: false)

    id = "s3-file-#{hash}"

    build_tmp_path(id)
  end

  def build_path_for_entry(%FSS.HTTP.Entry{} = entry) do
    hash =
      :crypto.hash(:sha256, entry.url) |> Base.url_encode64(padding: false)

    id = "http-file-#{hash}"

    build_tmp_path(id)
  end

  defp build_tmp_path(id) do
    base_dir = Path.join([System.tmp_dir!(), "elixir-explorer-datasets"])
    File.mkdir_p!(base_dir)

    Path.join([base_dir, id])
  end
end
