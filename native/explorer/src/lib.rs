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

#[cfg(feature = "cloud")]
mod cloud_writer;

mod dataframe;
mod datatypes;
mod encoding;
mod error;
mod expressions;
mod lazyframe;
mod series;

use dataframe::io::*;
use dataframe::*;
pub use datatypes::{
    ExDataFrame, ExDataFrameRef, ExExpr, ExExprRef, ExLazyFrame, ExLazyFrameRef, ExSeries,
    ExSeriesRef,
};
pub use error::ExplorerError;
use expressions::*;
use lazyframe::io::*;
use lazyframe::*;
use series::from_list::*;
use series::log::*;
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
        datetime_module = "Elixir.DateTime",
        duration_module = "Elixir.Explorer.Duration",
        naive_datetime_module = "Elixir.NaiveDateTime",
        time_module = "Elixir.Time",
        hour,
        minute,
        second,
        day,
        month,
        year,
        value,
        precision,
        millisecond,
        microsecond,
        nanosecond,
        calendar,
        nan,
        infinity,
        neg_infinity,
        std_offset,
        time_zone,
        utc_offset,
        zone_abbr,
    }
}

rustler::init!(
    "Elixir.Explorer.PolarsBackend.Native",
    [
        df_from_arrow_stream_pointer,
        df_sort_by,
        df_sort_with,
        df_concat_columns,
        df_nil_count,
        df_drop,
        df_dtypes,
        df_dump_csv,
        df_dump_ndjson,
        df_dump_parquet,
        df_dump_ipc,
        df_dump_ipc_stream,
        df_from_csv,
        df_from_ipc,
        df_from_ipc_stream,
        df_from_ndjson,
        df_from_parquet,
        df_from_series,
        df_group_indices,
        df_groups,
        df_load_csv,
        df_load_ndjson,
        df_load_parquet,
        df_load_ipc,
        df_load_ipc_stream,
        df_mask,
        df_n_rows,
        df_names,
        df_pivot_wider,
        df_pull,
        df_put_column,
        df_sample_frac,
        df_sample_n,
        df_select_at_idx,
        df_shape,
        df_slice,
        df_slice_by_indices,
        df_slice_by_series,
        df_transpose,
        df_to_csv,
        df_to_csv_cloud,
        df_to_dummies,
        df_to_ipc,
        df_to_ipc_cloud,
        df_to_ipc_stream,
        df_to_ipc_stream_cloud,
        df_lazy,
        df_to_ndjson,
        df_to_ndjson_cloud,
        df_to_parquet,
        df_to_parquet_cloud,
        df_width,
        df_re_dtype,
        // expressions
        expr_nil,
        expr_atom,
        expr_boolean,
        expr_cast,
        expr_column,
        expr_date,
        expr_naive_datetime,
        expr_datetime,
        expr_duration,
        expr_day_of_week,
        expr_day_of_year,
        expr_week_of_year,
        expr_month,
        expr_year,
        expr_hour,
        expr_minute,
        expr_second,
        expr_strptime,
        expr_strftime,
        expr_clip_integer,
        expr_clip_float,
        expr_fill_missing_with_strategy,
        expr_fill_missing_with_value,
        expr_float,
        expr_head,
        expr_integer,
        expr_int_range,
        expr_over,
        expr_peaks,
        expr_rank,
        expr_unary_not,
        expr_sample_frac,
        expr_sample_n,
        expr_series,
        expr_shift,
        expr_slice,
        expr_slice_by_indices,
        expr_string,
        expr_tail,
        // sort
        expr_argsort,
        expr_distinct,
        expr_reverse,
        expr_sort,
        expr_unordered_distinct,
        // comparison expressions
        expr_all_equal,
        expr_binary_and,
        expr_binary_or,
        expr_binary_in,
        expr_equal,
        expr_greater,
        expr_greater_equal,
        expr_is_finite,
        expr_is_infinite,
        expr_is_nan,
        expr_is_nil,
        expr_is_not_nil,
        expr_less,
        expr_less_equal,
        expr_not_equal,
        // arithmetic expressions
        expr_add,
        expr_abs,
        expr_divide,
        expr_multiply,
        expr_pow,
        expr_log,
        expr_log_natural,
        expr_exp,
        expr_quotient,
        expr_remainder,
        expr_subtract,
        // trigonometric expressions
        expr_acos,
        expr_asin,
        expr_atan,
        expr_cos,
        expr_sin,
        expr_tan,
        // slice and dice expressions
        expr_coalesce,
        expr_format,
        expr_concat,
        expr_select,
        // agg expressions
        expr_alias,
        expr_argmax,
        expr_argmin,
        expr_count,
        expr_first,
        expr_last,
        expr_max,
        expr_mean,
        expr_median,
        expr_min,
        expr_mode,
        expr_n_distinct,
        expr_nil_count,
        expr_quantile,
        expr_standard_deviation,
        expr_sum,
        expr_variance,
        expr_product,
        expr_size,
        expr_skew,
        expr_correlation,
        expr_covariance,
        expr_all,
        expr_any,
        // window expressions
        expr_cumulative_max,
        expr_cumulative_min,
        expr_cumulative_sum,
        expr_cumulative_product,
        expr_window_max,
        expr_window_mean,
        expr_window_median,
        expr_window_min,
        expr_window_sum,
        expr_window_standard_deviation,
        expr_ewm_mean,
        expr_ewm_standard_deviation,
        expr_ewm_variance,
        // inspect expressions
        expr_describe_filter_plan,
        // string expressions
        expr_contains,
        expr_re_contains,
        expr_upcase,
        expr_downcase,
        expr_strip,
        expr_lstrip,
        expr_rstrip,
        expr_substring,
        expr_split,
        expr_replace,
        expr_re_replace,
        expr_json_path_match,
        expr_split_into,
        expr_count_matches,
        expr_re_count_matches,
        expr_re_scan,
        expr_re_named_captures,
        // float round expressions
        expr_round,
        expr_floor,
        expr_ceil,
        // list expressions
        expr_join,
        expr_lengths,
        expr_member,
        // struct expressions
        expr_field,
        expr_json_decode,
        expr_struct,
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
        lf_slice,
        lf_explode,
        lf_unnest,
        lf_from_csv,
        lf_from_ipc,
        lf_from_parquet,
        lf_from_parquet_cloud,
        lf_from_ndjson,
        lf_filter_with,
        lf_sort_with,
        lf_grouped_sort_with,
        lf_distinct,
        lf_mutate_with,
        lf_summarise_with,
        lf_rename_columns,
        lf_drop_nils,
        lf_pivot_longer,
        lf_join,
        lf_concat_rows,
        lf_concat_columns,
        lf_sql,
        lf_to_parquet,
        lf_to_parquet_cloud,
        lf_to_ipc,
        lf_to_csv,
        // series
        s_as_str,
        s_abs,
        s_add,
        s_and,
        s_argmax,
        s_argmin,
        s_argsort,
        s_acos,
        s_asin,
        s_atan,
        s_cast,
        s_categories,
        s_categorise,
        s_coalesce,
        s_concat,
        s_contains,
        s_count_matches,
        s_re_scan,
        s_re_named_captures,
        s_cos,
        s_upcase,
        s_day_of_week,
        s_day_of_year,
        s_week_of_year,
        s_month,
        s_year,
        s_hour,
        s_minute,
        s_second,
        s_strptime,
        s_strftime,
        s_clip_integer,
        s_clip_float,
        s_downcase,
        s_cumulative_max,
        s_cumulative_min,
        s_cumulative_sum,
        s_cumulative_product,
        s_distinct,
        s_divide,
        s_dtype,
        s_equal,
        s_exp,
        s_fill_missing_with_strategy,
        s_fill_missing_with_bin,
        s_fill_missing_with_boolean,
        s_fill_missing_with_float,
        s_fill_missing_with_int,
        s_fill_missing_with_atom,
        s_fill_missing_with_date,
        s_fill_missing_with_datetime,
        s_greater,
        s_greater_equal,
        s_head,
        s_is_not_null,
        s_is_null,
        s_is_finite,
        s_is_infinite,
        s_is_nan,
        s_less,
        s_less_equal,
        s_lstrip,
        s_mask,
        s_max,
        s_mean,
        s_median,
        s_product,
        s_skew,
        s_correlation,
        s_covariance,
        s_all,
        s_any,
        s_min,
        s_mode,
        s_multiply,
        s_n_distinct,
        s_name,
        s_nil_count,
        s_not,
        s_log,
        s_log_natural,
        s_from_list_null,
        s_from_list_bool,
        s_from_list_date,
        s_from_list_time,
        s_from_list_naive_datetime,
        s_from_list_datetime,
        s_from_list_duration,
        s_from_list_f32,
        s_from_list_f64,
        s_from_list_s8,
        s_from_list_s16,
        s_from_list_s32,
        s_from_list_s64,
        s_from_list_u8,
        s_from_list_u16,
        s_from_list_u32,
        s_from_list_u64,
        s_from_list_str,
        s_from_list_binary,
        s_from_list_categories,
        s_from_list_of_series,
        s_from_list_of_series_as_structs,
        s_from_binary_f32,
        s_from_binary_f64,
        s_from_binary_s8,
        s_from_binary_s16,
        s_from_binary_s32,
        s_from_binary_s64,
        s_from_binary_u8,
        s_from_binary_u16,
        s_from_binary_u32,
        s_from_binary_u64,
        s_not_equal,
        s_or,
        s_peak_max,
        s_peak_min,
        s_select,
        s_quantile,
        s_quotient,
        s_rank,
        s_remainder,
        s_rename,
        s_replace,
        s_reverse,
        s_row_index,
        s_rstrip,
        s_sample_n,
        s_sample_frac,
        s_series_equal,
        s_shift,
        s_sin,
        s_size,
        s_slice,
        s_slice_by_indices,
        s_slice_by_series,
        s_sort,
        s_standard_deviation,
        s_tan,
        s_strip,
        s_substring,
        s_split,
        s_split_into,
        s_subtract,
        s_sum,
        s_tail,
        s_at,
        s_at_every,
        s_to_list,
        s_to_iovec,
        s_unordered_distinct,
        s_frequencies,
        s_cut,
        s_qcut,
        s_variance,
        s_window_max,
        s_window_mean,
        s_window_median,
        s_window_min,
        s_window_sum,
        s_window_standard_deviation,
        s_ewm_mean,
        s_ewm_standard_deviation,
        s_ewm_variance,
        s_in,
        s_round,
        s_floor,
        s_ceil,
        s_join,
        s_lengths,
        s_member,
        s_field,
        s_json_decode,
        s_json_path_match
    ],
    load = on_load
);
