defmodule Explorer.PolarsBackend.Expression do
  @moduledoc false
  # This module is responsible for translating the opaque LazySeries
  # to polars expressions in the Rust side.

  alias Explorer.DataFrame
  alias Explorer.Backend.LazySeries
  alias Explorer.PolarsBackend.Native
  alias Explorer.PolarsBackend.Series, as: PolarsSeries

  defstruct resource: nil

  @type t :: %__MODULE__{resource: reference()}

  @all_expressions [
    all_equal: 2,
    argmax: 1,
    argmin: 1,
    binary_and: 2,
    binary_or: 2,
    binary_in: 2,
    coalesce: 2,
    count: 1,
    day_of_week: 1,
    month: 1,
    year: 1,
    hour: 1,
    minute: 1,
    second: 1,
    distinct: 1,
    equal: 2,
    exp: 1,
    abs: 1,
    fill_missing_with_value: 2,
    first: 1,
    format: 1,
    greater: 2,
    greater_equal: 2,
    is_nil: 1,
    is_not_nil: 1,
    is_finite: 1,
    is_infinite: 1,
    is_nan: 1,
    last: 1,
    less: 2,
    less_equal: 2,
    max: 1,
    mean: 1,
    median: 1,
    min: 1,
    n_distinct: 1,
    nil_count: 1,
    not_equal: 2,
    unary_not: 1,
    pow: 2,
    product: 1,
    quotient: 2,
    remainder: 2,
    reverse: 1,
    floor: 1,
    ceil: 1,
    select: 3,
    sin: 1,
    cos: 1,
    tan: 1,
    asin: 1,
    acos: 1,
    atan: 1,
    standard_deviation: 1,
    subtract: 2,
    sum: 1,
    unordered_distinct: 1,
    variance: 1,
    skew: 2,
    covariance: 2
  ]

  @first_only_expressions [
    quantile: 2,
    argsort: 3,
    sort: 3,
    head: 2,
    tail: 2,
    peaks: 2,
    rank: 4,
    sample_n: 5,
    sample_frac: 5,
    exp: 1,
    skew: 2,
    round: 2,
    clip_float: 3,
    clip_integer: 3,

    # Trigonometric operations
    acos: 1,
    asin: 1,
    atan: 1,
    cos: 1,
    sin: 1,
    tan: 1,

    # Window operations
    cumulative_max: 2,
    cumulative_min: 2,
    cumulative_sum: 2,
    cumulative_product: 2,
    window_max: 5,
    window_mean: 5,
    window_median: 5,
    window_min: 5,
    window_sum: 5,
    window_standard_deviation: 5,
    ewm_mean: 5,

    # Conversions
    strptime: 2,
    strftime: 2,

    # Strings
    contains: 2,
    replace: 3,
    strip: 2,
    lstrip: 2,
    rstrip: 2,
    downcase: 1,
    upcase: 1,
    substring: 3
  ]

  @custom_expressions [
    add: 2,
    divide: 2,
    multiply: 2,
    cast: 2,
    fill_missing_with_strategy: 2,
    from_list: 2,
    from_binary: 2,
    log: 1,
    log: 2,
    lazy: 1,
    shift: 3,
    slice: 2,
    slice: 3,
    concat: 1,
    column: 1,
    correlation: 3
  ]

  missing =
    ((Explorer.Backend.LazySeries.operations() -- @all_expressions) -- @first_only_expressions) --
      @custom_expressions

  if missing != [] do
    raise ArgumentError, "missing #{inspect(__MODULE__)} nodes: #{inspect(missing)}"
  end

  def to_expr(%LazySeries{op: :cast, args: [lazy_series, dtype]}) do
    lazy_series_expr = to_expr(lazy_series)
    dtype_expr = Explorer.Shared.dtype_to_string(dtype)
    Native.expr_cast(lazy_series_expr, dtype_expr)
  end

  def to_expr(%LazySeries{op: :fill_missing_with_strategy, args: [lazy_series, strategy]}) do
    expr = to_expr(lazy_series)
    Native.expr_fill_missing_with_strategy(expr, Atom.to_string(strategy))
  end

  def to_expr(%LazySeries{op: :from_list, args: [list, dtype]}) do
    series = Explorer.PolarsBackend.Shared.from_list(list, dtype)
    Native.expr_series(series)
  end

  def to_expr(%LazySeries{op: :from_binary, args: [binary, dtype]}) do
    series = Explorer.PolarsBackend.Shared.from_binary(binary, dtype)
    Native.expr_series(series)
  end

  def to_expr(%LazySeries{op: :lazy, args: [data]}) do
    to_expr(data)
  end

  def to_expr(%LazySeries{op: :shift, args: [lazy_series, offset, nil]}) do
    Native.expr_shift(to_expr(lazy_series), offset, nil)
  end

  def to_expr(%LazySeries{op: :column, args: [name]}) do
    Native.expr_column(name)
  end

  def to_expr(%LazySeries{op: :concat, args: [series_list]}) when is_list(series_list) do
    expr_list = Enum.map(series_list, &to_expr/1)

    Native.expr_concat(expr_list)
  end

  def to_expr(%LazySeries{op: :correlation, args: [series1, series2, ddof]}) do
    Native.expr_correlation(to_expr(series1), to_expr(series2), ddof)
  end

  def to_expr(%LazySeries{op: :format, args: [series_list]}) when is_list(series_list) do
    expr_list = Enum.map(series_list, &to_expr/1)

    Native.expr_format(expr_list)
  end

  def to_expr(%LazySeries{op: :slice, args: [lazy_series, lazy_series_or_list]}) do
    indices =
      if is_list(lazy_series_or_list) do
        Explorer.PolarsBackend.Shared.from_list(lazy_series_or_list, :integer)
      else
        lazy_series_or_list
      end

    Native.expr_slice_by_indices(to_expr(lazy_series), to_expr(indices))
  end

  def to_expr(%LazySeries{op: :slice, args: [lazy_series, offset, length]}) do
    expr = to_expr(lazy_series)

    Native.expr_slice(expr, offset, length)
  end

  def to_expr(%LazySeries{op: :log, args: [lazy_series]}) do
    expr = to_expr(lazy_series)

    Native.expr_log_natural(expr)
  end

  def to_expr(%LazySeries{op: :log, args: [lazy_series, base]}) do
    expr = to_expr(lazy_series)

    Native.expr_log(expr, base)
  end

  for {op, _arity} <- @first_only_expressions do
    expr_op = :"expr_#{op}"

    def to_expr(%LazySeries{op: unquote(op), args: [lazy_series | args]}) do
      expr = to_expr(lazy_series)

      apply(Native, unquote(expr_op), [expr | args])
    end
  end

  def to_expr(%LazySeries{op: :add, args: [left, right]}) do
    # `duration + date` is not supported by polars for some reason.
    # `date + duration` is, so we're swapping arguments as a work around.
    [left, right] =
      case [dtype(left), dtype(right)] do
        [{:duration, _}, :date] -> [right, left]
        _ -> [left, right]
      end

    Native.expr_add(to_expr(left), to_expr(right))
  end

  def to_expr(%LazySeries{op: :multiply, args: [left, right] = args}) do
    expr = Native.expr_multiply(to_expr(left), to_expr(right))

    input_dtypes = Enum.map(args, &dtype/1)
    duration_dtype = Enum.find(input_dtypes, &match?({:duration, _}, &1))
    numeric? = Enum.any?(input_dtypes, &(&1 in [:integer, :float]))

    if duration_dtype && numeric? do
      wrap_in_cast(expr, duration_dtype)
    else
      expr
    end
  end

  def to_expr(%LazySeries{op: :divide, args: [left, right]}) do
    expr = Native.expr_divide(to_expr(left), to_expr(right))

    case {dtype(left), dtype(right)} do
      {{:duration, _} = left_dtype, right_dtype} when right_dtype in [:integer, :float] ->
        wrap_in_cast(expr, left_dtype)

      {_, _} ->
        expr
    end
  end

  for {op, arity} <- @all_expressions do
    args = Macro.generate_arguments(arity, __MODULE__)

    updates =
      for arg <- args do
        quote do
          to_expr(unquote(arg))
        end
      end

    expr_op = :"expr_#{op}"

    def to_expr(%LazySeries{op: unquote(op), args: unquote(args)}) do
      Native.unquote(expr_op)(unquote_splicing(updates))
    end
  end

  def to_expr(bool) when is_boolean(bool), do: Native.expr_boolean(bool)
  def to_expr(atom) when is_atom(atom), do: Native.expr_atom(Atom.to_string(atom))
  def to_expr(binary) when is_binary(binary), do: Native.expr_string(binary)
  def to_expr(number) when is_integer(number), do: Native.expr_integer(number)
  def to_expr(number) when is_float(number), do: Native.expr_float(number)
  def to_expr(%Date{} = date), do: Native.expr_date(date)
  def to_expr(%NaiveDateTime{} = datetime), do: Native.expr_datetime(datetime)
  def to_expr(%Explorer.Duration{} = duration), do: Native.expr_duration(duration)
  def to_expr(%PolarsSeries{} = polars_series), do: Native.expr_series(polars_series)

  # Used by Explorer.PolarsBackend.DataFrame
  def alias_expr(%__MODULE__{} = expr, alias_name) when is_binary(alias_name) do
    Native.expr_alias(expr, alias_name)
  end

  # Only for inspecting the expression in tests
  def describe_filter_plan(%DataFrame{data: polars_df}, %__MODULE__{} = expression) do
    Native.expr_describe_filter_plan(polars_df, expression)
  end

  defp wrap_in_cast(lazy_series_expr, dtype) do
    dtype_expr = Explorer.Shared.dtype_to_string(dtype)
    Native.expr_cast(lazy_series_expr, dtype_expr)
  end

  defp dtype(%LazySeries{dtype: dtype}), do: dtype

  defp dtype(%PolarsSeries{} = polars_series) do
    with {:ok, dtype} <- Native.s_dtype(polars_series) do
      Explorer.PolarsBackend.Shared.normalise_dtype(dtype)
    end
  end
end
