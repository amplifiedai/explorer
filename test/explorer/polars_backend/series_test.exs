defmodule Explorer.PolarsBackend.SeriesTest do
  use ExUnit.Case, async: true

  alias Explorer.PolarsBackend.Series

  describe "datetime resolution [ns]" do
    setup do
      # This is a dataframe with a single column called datetime with 3 values [~N[2023-04-19 16:14:35.474487],~N[2023-04-20 16:14:35.474487], ~N[2023-04-21 16:14:35.474487]] with datetime[ns] precession
      df = Explorer.DataFrame.from_parquet!("test/support/datetime_with_ns_res.parquet")
      series = Explorer.DataFrame.to_series(df)

      [series: series["datetime"]]
    end

    test "min", %{series: series} do
      assert Series.min(series) == ~N[2023-04-19 16:14:35.474487]
    end

    test "max", %{series: series} do
      assert Series.max(series) == ~N[2023-04-21 16:14:35.474487]
    end

    test "quantile", %{series: series} do
      assert Series.quantile(series, 0.5) == ~N[2023-04-20 16:14:35.474487]
    end

    test "day_of_week", %{series: series} do
      assert Series.day_of_week(series) == ~N[2023-04-20 16:14:35.474487]
    end
  end
end
