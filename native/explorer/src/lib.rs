// MiMalloc won´t compile on Windows with the GCC compiler.
// On Linux with Musl it won´t load correctly.
#[cfg(not(any(
    all(windows, target_env = "gnu"),
    all(target_os = "linux", target_env = "musl")
)))]
use mimalloc::MiMalloc;
use rustler::{Env, Term};

#[cfg(not(any(
    all(windows, target_env = "gnu"),
    all(target_os = "linux", target_env = "musl")
)))]
#[global_allocator]
static GLOBAL: MiMalloc = MiMalloc;

mod dataframe;
#[allow(clippy::extra_unused_lifetimes)]
mod datatypes;
mod encoding;
mod error;
mod expressions;
mod lazyframe;
mod series;

use dataframe::*;
pub use datatypes::{
    ExDataFrame, ExDataFrameRef, ExExpr, ExExprRef, ExLazyFrame, ExLazyFrameRef, ExSeries,
    ExSeriesRef,
};
pub use error::ExplorerError;
use expressions::*;
use lazyframe::*;
use series::*;

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(ExDataFrameRef, env);
    rustler::resource!(ExExprRef, env);
    rustler::resource!(ExLazyFrameRef, env);
    rustler::resource!(ExSeriesRef, env);
    true
}

mod atoms {
    rustler::atoms! {
        calendar_iso_module = "Elixir.Calendar.ISO",
        date_module = "Elixir.Date",
        naive_datetime_module = "Elixir.NaiveDateTime",
        hour,
        minute,
        second,
        day,
        month,
        year,
        microsecond,
        calendar,
        nan,
        infinity,
        neg_infinity
    }
}

rustler::init!(
    "Elixir.Explorer.PolarsBackend.Native",
    [
        df_arrange_with,
        df_pull,
        df_names,
        df_drop,
        df_distinct,
        df_drop_nulls,
        df_dtypes,
        df_filter_with,
        df_get_columns,
        df_groups,
        df_summarise_with_exprs,
        df_group_indices,
        df_head,
        df_n_rows,
        df_concat_columns,
        df_join,
        df_mask,
        df_pivot_longer,
        df_from_series,
        df_pivot_wider,
        df_from_csv,
        df_from_ipc,
        df_from_ipc_stream,
        df_from_parquet,
        df_from_ndjson,
        df_to_ndjson,
        df_select,
        df_select_at_idx,
        df_rename_columns,
        df_shape,
        df_slice,
        df_slice_by_indices,
        df_sample_n,
        df_sample_frac,
        df_arrange,
        df_tail,
        df_dump_csv,
        df_to_csv,
        df_to_dummies,
        df_to_lazy,
        df_concat_rows,
        df_width,
        df_mutate,
        df_mutate_with_exprs,
        df_to_ipc,
        df_to_ipc_stream,
        df_to_parquet,
        // expressions
        expr_boolean,
        expr_cast,
        expr_column,
        expr_date,
        expr_datetime,
        expr_float,
        expr_integer,
        expr_string,
        expr_series,
        expr_slice,
        expr_sample_n,
        expr_sample_frac,
        expr_head,
        expr_tail,
        expr_peaks,
        expr_fill_missing,
        expr_fill_missing_with_value,
        // sort
        expr_argsort,
        expr_distinct,
        expr_unordered_distinct,
        expr_reverse,
        expr_sort,
        // comparison expressions
        expr_binary_and,
        expr_binary_or,
        expr_equal,
        expr_greater,
        expr_greater_equal,
        expr_all_equal,
        expr_is_nil,
        expr_is_not_nil,
        expr_less,
        expr_less_equal,
        expr_not_equal,
        // arithmetic expressions
        expr_add,
        expr_subtract,
        expr_divide,
        expr_multiply,
        expr_pow,
        expr_quotient,
        expr_remainder,
        // slice and dice expressions
        expr_concat,
        expr_coalesce,
        // agg expressions
        expr_sum,
        expr_min,
        expr_max,
        expr_mean,
        expr_median,
        expr_n_distinct,
        expr_standard_deviation,
        expr_variance,
        expr_quantile,
        expr_alias,
        expr_count,
        expr_size,
        expr_first,
        expr_last,
        // window expressions
        expr_cumulative_max,
        expr_cumulative_min,
        expr_cumulative_sum,
        expr_window_max,
        expr_window_mean,
        expr_window_min,
        expr_window_sum,
        // inspect expressions
        expr_describe_filter_plan,
        // lazyframe
        lf_collect,
        lf_describe_plan,
        lf_drop,
        lf_dtypes,
        lf_fetch,
        lf_head,
        lf_names,
        lf_select,
        lf_tail,
        // series
        s_add,
        s_and,
        s_concat,
        s_argsort,
        s_as_str,
        s_cast,
        s_coalesce,
        s_cumulative_max,
        s_cumulative_min,
        s_cumulative_sum,
        s_distinct,
        s_divide,
        s_dtype,
        s_equal,
        s_fill_missing,
        s_fill_missing_with_int,
        s_fill_missing_with_float,
        s_fill_missing_with_bin,
        s_mask,
        s_fetch,
        s_greater,
        s_greater_equal,
        s_head,
        s_is_not_null,
        s_is_null,
        s_size,
        s_less,
        s_less_equal,
        s_max,
        s_mean,
        s_median,
        s_min,
        s_multiply,
        s_n_distinct,
        s_name,
        s_not_equal,
        s_new_bool,
        s_new_date32,
        s_new_date64,
        s_new_f64,
        s_new_i64,
        s_new_str,
        s_or,
        s_peak_max,
        s_peak_min,
        s_pow_f_rhs,
        s_pow_f_lhs,
        s_pow_i_rhs,
        s_pow_i_lhs,
        s_quantile,
        s_quotient,
        s_remainder,
        s_rename,
        s_reverse,
        s_window_max,
        s_window_mean,
        s_window_min,
        s_window_sum,
        s_seedable_random_indices,
        s_series_equal,
        s_slice,
        s_slice_by_indices,
        s_sort,
        s_standard_deviation,
        s_subtract,
        s_sum,
        s_tail,
        s_take_every,
        s_to_list,
        s_unordered_distinct,
        s_variance,
        s_value_counts,
    ],
    load = on_load
);
