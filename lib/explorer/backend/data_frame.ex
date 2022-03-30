defmodule Explorer.Backend.DataFrame do
  @moduledoc """
  The behaviour for DataFrame backends.
  """

  @type t :: %{__struct__: atom()}

  @type df :: Explorer.DataFrame.t()
  @type result(t) :: {:ok, t} | {:error, term()}
  @type series :: Explorer.Series.t()
  @type colname :: String.t()

  # IO

  @callback read_csv(
              filename :: String.t(),
              names :: list(String.t()) | nil,
              dtypes :: list({String.t(), atom()}) | nil,
              delimiter :: String.t(),
              null_character :: String.t(),
              skip_rows :: integer(),
              header? :: boolean(),
              encoding :: String.t(),
              max_rows :: integer() | Inf,
              with_columns :: list(String.t()) | nil,
              infer_schema_length :: integer() | nil,
              parse_dates :: boolean()
            ) :: result(df)
  @callback write_csv(df, filename :: String.t(), header? :: boolean(), delimiter :: String.t()) ::
              result(String.t())

  @callback read_parquet(filename :: String.t()) :: result(df)
  @callback write_parquet(df, filename :: String.t()) :: result(String.t())

  @callback read_ipc(filename :: String.t()) :: result(df)
  @callback write_ipc(df, filename :: String.t()) :: result(String.t())

  # Conversion

  @callback from_columns(map() | Keyword.t()) :: df
  @callback from_rows(list(map() | Keyword.t())) :: df
  @callback to_map(df, convert_series? :: boolean()) :: map()
  @callback to_binary(df, header? :: boolean(), delimiter :: String.t()) :: String.t()

  # Introspection

  @callback names(df) :: [colname]
  @callback dtypes(df) :: [String.t()]
  @callback shape(df) :: {integer(), integer()}
  @callback n_rows(df) :: integer()
  @callback n_cols(df) :: integer()

  # Single table verbs

  @callback head(df, rows :: integer()) :: df
  @callback tail(df, rows :: integer()) :: df
  @callback select(df, columns :: [colname], :keep | :drop) :: df
  @callback filter(df, mask :: series) :: df
  @callback mutate(df, with_columns :: map()) :: df
  @callback arrange(df, columns :: [colname | {:asc | :desc, colname}]) :: df
  @callback distinct(df, columns :: [colname], keep_all? :: boolean()) :: df
  @callback rename(df, [colname]) :: df
  @callback dummies(df, columns :: [colname]) :: df
  @callback sample(df, n :: integer(), with_replacement? :: boolean(), seed :: integer()) :: df
  @callback pull(df, column :: String.t()) :: series
  @callback slice(df, offset :: integer(), length :: integer()) :: df
  @callback take(df, indices :: list(integer())) :: df
  @callback drop_nil(df, columns :: [colname]) :: df
  @callback pivot_wider(
              df,
              id_cols :: [colname],
              names_from :: [colname],
              values_from ::
                [colname],
              names_prefix :: String.t()
            ) :: df
  @callback pivot_longer(
              df,
              id_cols :: [colname],
              value_cols :: [colname],
              names_to :: colname,
              values_to :: colname
            ) :: df

  # Two or more table verbs

  @callback join(
              left :: df,
              right :: df,
              on :: list(String.t() | {String.t(), String.t()}),
              how :: :left | :inner | :outer | :right | :cross
            ) :: df

  @callback concat_rows([df]) :: df

  # Groups

  @callback group_by(df, columns :: [colname]) :: df
  @callback ungroup(df, columns :: [colname]) :: df
  @callback summarise(df, aggregations :: map()) :: df
end
