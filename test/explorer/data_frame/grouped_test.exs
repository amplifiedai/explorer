defmodule Explorer.DataFrame.GroupedTest do
  use ExUnit.Case, async: true

  alias Explorer.DataFrame, as: DF
  alias Explorer.Datasets
  alias Explorer.Series

  setup do
    df = Datasets.fossil_fuels()
    {:ok, df: df}
  end

  describe "group_by/2" do
    test "groups a dataframe by one column", %{df: df} do
      assert df.groups == []
      df1 = DF.group_by(df, "country")

      assert df1.groups == ["country"]
      assert DF.groups(df1) == ["country"]
    end

    test "groups a dataframe by two columns", %{df: df} do
      df1 = DF.group_by(df, ["country", "year"])

      assert df1.groups == ["country", "year"]
      assert DF.groups(df1) == ["country", "year"]
    end

    test "adds a group for an already grouped dataframe", %{df: df} do
      df1 = DF.group_by(df, ["country"])
      df2 = DF.group_by(df1, "year")

      assert df2.groups == ["country", "year"]
      assert DF.groups(df2) == ["country", "year"]
    end

    test "raise error for unknown columns", %{df: df} do
      assert_raise ArgumentError, "could not find column name \"something_else\"", fn ->
        DF.group_by(df, "something_else")
      end
    end
  end

  describe "ungroup/2" do
    test "removes one group", %{df: df} do
      df1 = DF.group_by(df, "country")
      df2 = DF.ungroup(df1, "country")

      assert df2.groups == []
      assert DF.groups(df2) == []
    end

    test "remove one group for a dataframe that is grouped by two groups", %{df: df} do
      df1 = DF.group_by(df, ["country", "year"])
      df2 = DF.ungroup(df1, "country")

      assert df2.groups == ["year"]
      assert DF.groups(df2) == ["year"]
    end

    test "remove two groups of a dataframe", %{df: df} do
      df1 = DF.group_by(df, ["country", "year"])
      df2 = DF.ungroup(df1, ["year", "country"])

      assert df2.groups == []
      assert DF.groups(df2) == []
    end

    test "raise error for unknown groups", %{df: df} do
      df1 = DF.group_by(df, ["country", "year"])

      assert_raise ArgumentError, "could not find column name \"something_else\"", fn ->
        DF.ungroup(df1, ["something_else"])
      end
    end
  end

  describe "summarise/2" do
    test "with one group and one column with aggregations", %{df: df} do
      df1 = df |> DF.group_by("year") |> DF.summarise(total: [:max, :min])

      assert DF.to_columns(df1, atom_keys: true) == %{
               year: [2010, 2011, 2012, 2013, 2014],
               total_min: [1, 2, 2, 2, 3],
               total_max: [2_393_248, 2_654_360, 2_734_817, 2_797_384, 2_806_634]
             }
    end

    test "with one group and two columns with aggregations", %{df: df} do
      df1 = df |> DF.group_by("year") |> DF.summarise(total: [:max, :min], country: [:n_unique])

      assert DF.to_columns(df1, atom_keys: true) == %{
               year: [2010, 2011, 2012, 2013, 2014],
               total_min: [1, 2, 2, 2, 3],
               total_max: [2_393_248, 2_654_360, 2_734_817, 2_797_384, 2_806_634],
               country_n_unique: [217, 217, 220, 220, 220]
             }
    end

    test "with two groups and one column with aggregations", %{df: df} do
      df1 =
        df |> DF.head(5) |> DF.group_by(["country", "year"]) |> DF.summarise(total: [:max, :min])

      assert DF.to_columns(df1, atom_keys: true) == %{
               year: [2010, 2010, 2010, 2010, 2010],
               country: ["AFGHANISTAN", "ALBANIA", "ALGERIA", "ANDORRA", "ANGOLA"],
               total_max: [2308, 1254, 32500, 141, 7924],
               total_min: [2308, 1254, 32500, 141, 7924]
             }
    end

    test "with two groups and two columns with aggregations", %{df: df} do
      equal_filters =
        for country <- ["BRAZIL", "AUSTRALIA", "POLAND"], do: Series.equal(df["country"], country)

      filters = Enum.reduce(equal_filters, fn filter, acc -> Series.or(acc, filter) end)

      df1 =
        df
        |> DF.filter(filters)
        |> DF.group_by(["country", "year"])
        |> DF.summarise(total: [:max, :min], cement: [:median])
        |> DF.arrange(:country)

      assert DF.to_columns(df1, atom_keys: true) == %{
               country: [
                 "AUSTRALIA",
                 "AUSTRALIA",
                 "AUSTRALIA",
                 "AUSTRALIA",
                 "AUSTRALIA",
                 "BRAZIL",
                 "BRAZIL",
                 "BRAZIL",
                 "BRAZIL",
                 "BRAZIL",
                 "POLAND",
                 "POLAND",
                 "POLAND",
                 "POLAND",
                 "POLAND"
               ],
               year: [
                 2010,
                 2011,
                 2012,
                 2013,
                 2014,
                 2010,
                 2011,
                 2012,
                 2013,
                 2014,
                 2010,
                 2011,
                 2012,
                 2013,
                 2014
               ],
               total_min: [
                 106_589,
                 106_850,
                 105_843,
                 101_518,
                 98517,
                 114_468,
                 119_829,
                 128_178,
                 137_354,
                 144_480,
                 86246,
                 86446,
                 81792,
                 82432,
                 77922
               ],
               total_max: [
                 106_589,
                 106_850,
                 105_843,
                 101_518,
                 98517,
                 114_468,
                 119_829,
                 128_178,
                 137_354,
                 144_480,
                 86246,
                 86446,
                 81792,
                 82432,
                 77922
               ],
               cement_median: [
                 1129.0,
                 1170.0,
                 1156.0,
                 1142.0,
                 1224.0,
                 8040.0,
                 8717.0,
                 9428.0,
                 9517.0,
                 9691.0,
                 2111.0,
                 2523.0,
                 2165.0,
                 1977.0,
                 2089.0
               ]
             }
    end

    test "pull from summarised DF", %{df: df} do
      series =
        df
        |> DF.group_by("country")
        |> DF.summarise(total: [:count])
        |> DF.pull("total_count")

      assert Series.min(series) == 2
    end
  end

  describe "summarise_with/2" do
    test "with one group and one column with aggregations", %{df: df} do
      df1 =
        df
        |> DF.group_by("year")
        |> DF.summarise_with(fn ldf ->
          total = ldf["total"]

          [total_min: Series.min(total), total_max: Series.max(total)]
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               year: [2010, 2011, 2012, 2013, 2014],
               total_min: [1, 2, 2, 2, 3],
               total_max: [2_393_248, 2_654_360, 2_734_817, 2_797_384, 2_806_634]
             }
    end

    test "with one group and two columns with aggregations", %{df: df} do
      df1 =
        df
        |> DF.group_by("year")
        |> DF.summarise_with(fn ldf ->
          total = ldf["total"]
          liquid_fuel = ldf["liquid_fuel"]

          [
            total_min: Series.min(total),
            total_max: Series.max(total),
            median_liquid_fuel: Series.median(liquid_fuel)
          ]
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               year: [2010, 2011, 2012, 2013, 2014],
               total_min: [1, 2, 2, 2, 3],
               total_max: [2_393_248, 2_654_360, 2_734_817, 2_797_384, 2_806_634],
               median_liquid_fuel: [1193.0, 1236.0, 1199.0, 1260.0, 1255.0]
             }
    end

    test "with one group and aggregations with addition and subtraction", %{df: df} do
      df1 =
        df
        |> DF.group_by("year")
        |> DF.summarise_with(fn ldf ->
          total = ldf["total"]
          liquid_fuel = ldf["liquid_fuel"]

          [
            total_min: Series.min(Series.add(total, 4)),
            total_max: Series.max(Series.subtract(total, liquid_fuel))
          ]
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               year: [2010, 2011, 2012, 2013, 2014],
               total_min: [5, 6, 6, 6, 7],
               total_max: [2_095_057, 2_347_630, 2_413_662, 2_460_424, 2_461_909]
             }
    end

    test "with two groups and one column with aggregations", %{df: df} do
      df1 =
        df
        |> DF.head(5)
        |> DF.group_by(["country", "year"])
        |> DF.summarise_with(fn ldf ->
          total = ldf["total"]

          [total_min: Series.min(total), total_max: Series.max(total)]
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               year: [2010, 2010, 2010, 2010, 2010],
               country: ["AFGHANISTAN", "ALBANIA", "ALGERIA", "ANDORRA", "ANGOLA"],
               total_max: [2308, 1254, 32500, 141, 7924],
               total_min: [2308, 1254, 32500, 141, 7924]
             }
    end
  end

  describe "arrange/2" do
    test "sorts by group", %{df: df} do
      df = DF.arrange(df, "total")
      grouped_df = df |> DF.group_by("country") |> DF.arrange("total")

      assert df["total"][0] == Series.min(df["total"])

      assert grouped_df
             |> DF.ungroup()
             |> DF.filter(&Series.equal(&1["country"], "HONDURAS"))
             |> DF.pull("total")
             |> Series.first() == 2175
    end
  end

  describe "mutate/2" do
    test "adds a new column when there is a group" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"], c: [1, 1, 2])

      df1 = DF.group_by(df, :c)
      df2 = DF.mutate(df1, d: &Series.add(&1["a"], -7.1))

      assert DF.to_columns(df2, atom_keys: true) == %{
               a: [1, 2, 3],
               b: ["a", "b", "c"],
               c: [1, 1, 2],
               d: [-6.1, -5.1, -4.1]
             }

      assert df2.names == ["a", "b", "c", "d"]
      assert df2.dtypes == %{"a" => :integer, "b" => :string, "c" => :integer, "d" => :float}
      assert df2.groups == ["c"]
    end
  end

  describe "distinct/2" do
    test "with one group", %{df: df} do
      df1 = DF.group_by(df, "year")

      df2 = DF.distinct(df1, columns: [:country])
      assert DF.names(df2) == ["year", "country"]
      assert DF.groups(df2) == ["year"]
      assert DF.shape(df2) == {1094, 2}
    end

    test "with one group and distinct as the same", %{df: df} do
      df1 = DF.group_by(df, "country")
      df2 = DF.distinct(df1, columns: [:country])

      assert DF.names(df2) == ["country"]
      assert DF.groups(df2) == ["country"]
      assert DF.shape(df2) == {222, 1}
    end

    test "multiple groups and different distinct", %{df: df} do
      df1 = DF.group_by(df, ["country", "year"])

      df2 = DF.distinct(df1, columns: [:bunker_fuels])
      assert DF.names(df2) == ["country", "year", "bunker_fuels"]
      assert DF.groups(df2) == ["country", "year"]
      assert DF.shape(df2) == {1094, 3}
    end

    test "with groups and keeping all", %{df: df} do
      df1 = DF.group_by(df, "year")

      df2 = DF.distinct(df1, columns: [:country], keep_all?: true)

      assert DF.names(df2) == [
               "year",
               "country",
               "total",
               "solid_fuel",
               "liquid_fuel",
               "gas_fuel",
               "cement",
               "gas_flaring",
               "per_capita",
               "bunker_fuels"
             ]

      assert DF.groups(df2) == ["year"]

      assert DF.shape(df2) == {1094, 10}
    end
  end
end
