defmodule Explorer.DataFrameTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  doctest Explorer.DataFrame

  alias Explorer.DataFrame, as: DF
  alias Explorer.Datasets
  alias Explorer.Series

  setup do
    {:ok, df: Datasets.fossil_fuels()}
  end

  defp tmp_csv(tmp_dir, contents) do
    path = Path.join(tmp_dir, "tmp.csv")
    :ok = File.write!(path, contents)
    path
  end

  # Tests for summarize, group, ungroup are available in grouped_test.exs

  describe "mask/2" do
    test "raises with mask of invalid size", %{df: df} do
      assert_raise ArgumentError,
                   "size of the mask (3) must match number of rows in the dataframe (1094)",
                   fn -> DF.mask(df, [true, false, true]) end
    end
  end

  describe "filter_with/2" do
    test "filter a column that is equal to a value" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [5.3, 2.4, 1.0, 0.2, 6.1, 2.1, 2.2])

      df1 = DF.filter_with(df, fn ldf -> Series.equal(ldf["a"], 5) end)
      assert DF.to_columns(df1, atom_keys: true) == %{a: [5, 5], b: [6.1, 2.2]}

      df2 = DF.filter_with(df, fn ldf -> Series.equal(ldf["b"], 2.1) end)
      assert DF.to_columns(df2, atom_keys: true) == %{a: [6], b: [2.1]}

      df3 = DF.filter_with(df, fn ldf -> Series.equal(ldf["b"], 52.1) end)
      assert DF.to_columns(df3, atom_keys: true) == %{a: [], b: []}
    end

    test "filter a column that has values equal to the other column" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9, 8, 7, 6, 5, 4, 3])

      df1 = DF.filter_with(df, fn ldf -> Series.equal(ldf["a"], ldf["b"]) end)
      assert DF.to_columns(df1, atom_keys: true) == %{a: [5], b: [5]}
    end

    test "filter by a string value" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

      df1 = DF.filter_with(df, fn ldf -> Series.equal(ldf["b"], "b") end)
      assert DF.to_columns(df1, atom_keys: true) == %{a: [2], b: ["b"]}
    end

    test "filter by a boolean value" do
      df = DF.new(a: [1, 2, 3], b: [true, true, false])

      df1 = DF.filter_with(df, fn ldf -> Series.equal(ldf["b"], false) end)
      assert DF.to_columns(df1, atom_keys: true) == %{a: [3], b: [false]}
    end

    test "filter by a given date" do
      df = DF.new(a: [1, 2, 3], b: [~D[2022-07-07], ~D[2022-07-08], ~D[2022-07-09]])

      df1 = DF.filter_with(df, fn ldf -> Series.equal(ldf["b"], ~D[2022-07-07]) end)
      assert DF.to_columns(df1, atom_keys: true) == %{a: [1], b: [~D[2022-07-07]]}
    end

    test "filter by a given datetime" do
      df =
        DF.new(
          a: [1, 2, 3],
          b: [
            ~N[2022-07-07 17:43:08.473561],
            ~N[2022-07-07 17:44:13.020548],
            ~N[2022-07-07 17:45:00.116337]
          ]
        )

      df1 =
        DF.filter_with(df, fn ldf -> Series.greater(ldf["b"], ~N[2022-07-07 17:44:13.020548]) end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [3], b: [~N[2022-07-07 17:45:00.116337]]}
    end

    test "filter with a complex filter" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9, 8, 7, 6, 5, 4, 3])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          # a > 5 or a <= 2 and b != 9
          Series.greater(a, 5)
          |> Series.or(Series.less_equal(a, 2))
          |> Series.and(Series.not_equal(b, 9))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [2, 6], b: [8, 4]}
    end

    test "filter for nil values" do
      df = DF.new(a: [1, 2, 3, nil, 5, nil, 5], b: [9, 8, 7, 6, 5, 4, 3])

      df1 =
        DF.filter_with(df, fn ldf ->
          Series.is_nil(ldf["a"])
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [nil, nil], b: [6, 4]}
    end

    test "filter for not nil values" do
      df = DF.new(a: [1, 2, 3, nil, 5, nil, 5], b: [9, 8, 7, 6, 5, 4, 3])

      df1 =
        DF.filter_with(df, fn ldf ->
          Series.is_not_nil(ldf["a"])
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [1, 2, 3, 5, 5], b: [9, 8, 7, 5, 3]}
    end

    test "filter with add operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9, 8, 7, 6, 5, 4, 3])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          # a > (b + 1)
          Series.greater(a, Series.add(b, 1))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [6, 5], b: [4, 3]}
    end

    test "filter with subtract operation" do
      df = DF.new(a: [1.1, 2.2, 3.3, 4.4, 5.5, 6.5, 5.8], b: [9, 8, 7, 6, 5, 4, 3])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          # a > (b - a)
          Series.greater(a, Series.subtract(b, a))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [4.4, 5.5, 6.5, 5.8], b: [6, 5, 4, 3]}
    end

    test "filter with divide operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9, 8, 7, 6, 5, 4, 3])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          # a > (b / 3)
          Series.greater(a, Series.divide(b, 3))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [3, 4, 5, 6, 5], b: [7, 6, 5, 4, 3]}
    end

    test "filter with pow operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9.2, 8.0, 7.1, 6.0, 5.0, 4.0, 3.2])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          # b == (a ** 3)
          Series.equal(b, Series.pow(a, 3))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [2], b: [8.0]}
    end

    test "filter with count operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9.2, 8.0, 7.1, 6.0, 5.0, 4.0, 3.2])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          Series.greater(b, Series.count(a))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [1, 2, 3], b: [9.2, 8.0, 7.1]}
    end

    test "filter with max operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9.2, 8.0, 7.1, 6.0, 5.0, 4.0, 3.2])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          Series.greater(b, Series.max(a))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [1, 2, 3], b: [9.2, 8.0, 7.1]}
    end

    test "filter with last operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9.2, 8.0, 7.1, 6.0, 5.0, 4.0, 3.2])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]

          Series.greater(b, Series.last(a))
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [1, 2, 3, 4], b: [9.2, 8.0, 7.1, 6.0]}
    end

    test "filter with coalesce operation" do
      df = DF.new(a: [1, nil, 3, nil], b: [nil, 2, nil, 4])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]
          c = Series.coalesce(a, b)

          Series.greater(c, 3)
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [nil], b: [4]}

      df2 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          b = ldf["b"]
          c = Series.coalesce(a, b)

          Series.is_nil(c)
        end)

      assert DF.to_columns(df2, atom_keys: true) == %{a: [], b: []}
    end

    test "filter with window operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9.2, 8.0, 7.1, 6.0, 5.0, 4.0, 3.2])

      df1 =
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]
          c = Series.window_mean(a, 3)

          Series.greater(a, c)
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [2, 3, 4, 5, 6],
               b: [8.0, 7.1, 6.0, 5.0, 4.0]
             }
    end

    test "raise an error if the last operation is an arithmetic operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9, 8, 7, 6, 5, 4, 3])

      message =
        "expecting the function to return a boolean LazySeries, but instead it returned a LazySeries of type :integer"

      assert_raise ArgumentError, message, fn ->
        DF.filter_with(df, fn ldf ->
          a = ldf["a"]

          Series.pow(a, 3)
        end)
      end
    end

    test "raise an error if the last operation is an aggregation operation" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9, 8, 7, 6, 5, 4, 3])

      message =
        "expecting the function to return a boolean LazySeries, " <>
          "but instead it returned a LazySeries of type :integer"

      assert_raise ArgumentError, message, fn ->
        DF.filter_with(df, fn ldf ->
          Series.sum(ldf["a"])
        end)
      end
    end

    test "raise an error if the function is not returning a lazy series" do
      df = DF.new(a: [1, 2, 3, 4, 5, 6, 5], b: [9, 8, 7, 6, 5, 4, 3])
      message = "expecting the function to return a LazySeries, but instead it returned :foo"

      assert_raise ArgumentError, message, fn ->
        DF.filter_with(df, fn _ldf -> :foo end)
      end
    end
  end

  describe "mutate/2" do
    test "adds a new column" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])
      df1 = DF.mutate(df, c: [true, false, true])

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 3],
               b: ["a", "b", "c"],
               c: [true, false, true]
             }

      assert df1.names == ["a", "b", "c"]
      assert df1.dtypes == %{"a" => :integer, "b" => :string, "c" => :boolean}
    end

    test "raises with series of invalid size", %{df: df} do
      assert_raise ArgumentError,
                   "size of new column test (3) must match number of rows in the dataframe (1094)",
                   fn -> DF.mutate(df, test: [1, 2, 3]) end
    end

    test "keeps the column order" do
      df = DF.new(e: [1, 2, 3], c: ["a", "b", "c"], a: [1.2, 2.3, 4.5])

      df1 = DF.mutate(df, d: 1, b: 2)

      assert df1.names == ["e", "c", "a", "d", "b"]
    end
  end

  describe "mutate_with/2" do
    test "adds a new column" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

      df1 =
        DF.mutate_with(df, fn ldf ->
          [c: Series.add(ldf["a"], 5)]
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 3],
               b: ["a", "b", "c"],
               c: [6, 7, 8]
             }

      assert df1.names == ["a", "b", "c"]
      assert df1.dtypes == %{"a" => :integer, "b" => :string, "c" => :integer}
    end

    test "adds a new column with some aggregations without groups" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

      df1 =
        DF.mutate_with(df, fn ldf ->
          a = ldf["a"]

          [
            c: Series.first(a),
            d: Series.last(a),
            e: Series.count(a),
            f: Series.median(a),
            g: Series.sum(a),
            h: Series.min(a) |> Series.add(a),
            i: Series.quantile(a, 0.2)
          ]
        end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 3],
               b: ["a", "b", "c"],
               c: [1, 1, 1],
               d: [3, 3, 3],
               e: [3, 3, 3],
               f: [2.0, 2.0, 2.0],
               g: [6, 6, 6],
               h: [2, 3, 4],
               i: [1, 1, 1]
             }

      assert df1.names == ["a", "b", "c", "d", "e", "f", "g", "h", "i"]

      assert df1.dtypes == %{
               "a" => :integer,
               "b" => :string,
               "c" => :integer,
               "d" => :integer,
               "e" => :integer,
               "f" => :float,
               "g" => :integer,
               "h" => :integer,
               "i" => :integer
             }
    end

    test "adds some columns with window functions" do
      df = DF.new(a: Enum.to_list(1..10))

      df1 =
        DF.mutate_with(df, fn ldf ->
          a = ldf["a"]

          [
            b: Series.window_max(a, 2, weights: [1.0, 2.0]),
            c: Series.window_mean(a, 2, weights: [1.0, 2.0]),
            d: Series.window_min(a, 2, weights: [1.0, 2.0]),
            e: Series.window_sum(a, 2, weights: [1.0, 2.0]),
            f: Series.cumulative_max(a),
            g: Series.cumulative_min(a),
            h: Series.cumulative_sum(a),
            i: Series.cumulative_max(a, reverse: true)
          ]
        end)

      assert df1.dtypes == %{
               "a" => :integer,
               "b" => :float,
               "c" => :float,
               "d" => :float,
               "e" => :float,
               "f" => :integer,
               "g" => :integer,
               "h" => :integer,
               "i" => :integer
             }

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
               b: [1.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0],
               c: [1.0, 2.5, 4.0, 5.5, 7.0, 8.5, 10.0, 11.5, 13.0, 14.5],
               d: [1.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0],
               e: [1.0, 5.0, 8.0, 11.0, 14.0, 17.0, 20.0, 23.0, 26.0, 29.0],
               f: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
               g: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
               h: [1, 3, 6, 10, 15, 21, 28, 36, 45, 55],
               i: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10]
             }
    end
  end

  describe "arrange/3" do
    test "raises with invalid column names", %{df: df} do
      assert_raise ArgumentError,
                   "could not find column name \"test\"",
                   fn -> DF.arrange(df, ["test"]) end
    end
  end

  describe "arrange_with/2" do
    test "with a simple df and asc order" do
      df = DF.new(a: [1, 2, 4, 3, 6, 5], b: ["a", "b", "d", "c", "f", "e"])
      df1 = DF.arrange_with(df, fn ldf -> [asc: ldf["a"]] end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 3, 4, 5, 6],
               b: ["a", "b", "c", "d", "e", "f"]
             }
    end

    test "with a simple df and desc order" do
      df = DF.new(a: [1, 2, 4, 3, 6, 5], b: ["a", "b", "d", "c", "f", "e"])
      df1 = DF.arrange_with(df, fn ldf -> [desc: ldf["a"]] end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [6, 5, 4, 3, 2, 1],
               b: ["f", "e", "d", "c", "b", "a"]
             }
    end

    test "with a simple df and just the lazy series" do
      df = DF.new(a: [1, 2, 4, 3, 6, 5], b: ["a", "b", "d", "c", "f", "e"])
      df1 = DF.arrange_with(df, fn ldf -> [ldf["a"]] end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 3, 4, 5, 6],
               b: ["a", "b", "c", "d", "e", "f"]
             }
    end

    test "with a simple df and arrange by two columns" do
      df = DF.new(a: [1, 2, 2, 3, 6, 5], b: [1.1, 2.5, 2.2, 3.3, 4.0, 5.1])
      df1 = DF.arrange_with(df, fn ldf -> [asc: ldf["a"], asc: ldf["b"]] end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 2, 3, 5, 6],
               b: [1.1, 2.2, 2.5, 3.3, 5.1, 4.0]
             }
    end

    test "with a simple df and window function" do
      df = DF.new(a: [1, 2, 4, 3, 6, 5], b: ["a", "b", "d", "c", "f", "e"])
      df1 = DF.arrange_with(df, fn ldf -> [desc: Series.window_mean(ldf["a"], 2)] end)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [5, 6, 3, 4, 2, 1],
               b: ["e", "f", "c", "d", "b", "a"]
             }
    end

    test "without a lazy series" do
      df = DF.new(a: [1, 2])

      assert_raise RuntimeError, "expecting a lazy series, but got :foo.", fn ->
        DF.arrange_with(df, fn _ldf -> [desc: :foo] end)
      end
    end

    test "with wrong direction" do
      df = DF.new(a: [1, 2])

      message = "expecting a valid direction, which is :asc or :desc, but got :descending."

      assert_raise RuntimeError, message, fn ->
        DF.arrange_with(df, fn ldf -> [descending: ldf["a"]] end)
      end
    end
  end

  describe "slice/2" do
    test "slice with indexes" do
      df = DF.new(a: [1, 2, 3, 4, 5])

      df1 = DF.slice(df, [2, 4])

      assert DF.to_columns(df1, atom_keys: true) == %{a: [3, 5]}
    end

    test "slice with ranges" do
      df = DF.new(a: [1, 2, 3, 4, 5])

      df1 = DF.slice(df, -3..-1)

      assert DF.to_columns(df1, atom_keys: true) == %{a: [3, 4, 5]}
    end

    test "raises with index out of bounds", %{df: df} do
      assert_raise ArgumentError,
                   "requested row index (2000) out of bounds (-1094:1094)",
                   fn -> DF.slice(df, [1, 2, 3, 2000]) end
    end
  end

  describe "join/3" do
    test "raises if no overlapping columns" do
      assert_raise ArgumentError,
                   "could not find any overlapping columns",
                   fn ->
                     left = DF.new(a: [1, 2, 3])
                     right = DF.new(b: [1, 2, 3])
                     DF.join(left, right)
                   end
    end

    test "doesn't raise if no overlapping columns on cross join" do
      left = DF.new(a: [1, 2, 3])
      right = DF.new(b: [1, 2, 3])
      joined = DF.join(left, right, how: :cross)
      assert %DF{} = joined
    end

    test "with a custom 'on'" do
      left = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])
      right = DF.new(d: [1, 2, 2], c: ["d", "e", "f"])

      df = DF.join(left, right, on: [{"a", "d"}])

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [1, 2, 2],
               b: ["a", "b", "b"],
               c: ["d", "e", "f"]
             }
    end

    test "with a custom 'on' but with repeated column on right side" do
      left = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])
      right = DF.new(d: [1, 2, 2], c: ["d", "e", "f"], a: [5, 6, 7])

      df = DF.join(left, right, on: [{"a", "d"}])

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [1, 2, 2],
               b: ["a", "b", "b"],
               c: ["d", "e", "f"],
               a_right: [5, 6, 7]
             }

      assert df.names == ["a", "b", "c", "a_right"]

      df1 = DF.join(left, right, on: [{"a", "d"}], how: :left)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 2, 3],
               b: ["a", "b", "b", "c"],
               c: ["d", "e", "f", nil],
               a_right: [5, 6, 7, nil]
             }

      assert df1.names == ["a", "b", "c", "a_right"]

      df2 = DF.join(left, right, on: [{"a", "d"}], how: :outer)

      assert DF.to_columns(df2, atom_keys: true) == %{
               a: [1, 2, 2, 3],
               b: ["a", "b", "b", "c"],
               c: ["d", "e", "f", nil],
               a_right: [5, 6, 7, nil]
             }

      assert df2.names == ["a", "b", "c", "a_right"]

      df3 = DF.join(left, right, how: :cross)

      assert DF.to_columns(df3, atom_keys: true) == %{
               a: [1, 1, 1, 2, 2, 2, 3, 3, 3],
               a_right: [5, 6, 7, 5, 6, 7, 5, 6, 7],
               b: ["a", "a", "a", "b", "b", "b", "c", "c", "c"],
               c: ["d", "e", "f", "d", "e", "f", "d", "e", "f"],
               d: [1, 2, 2, 1, 2, 2, 1, 2, 2]
             }

      assert df3.names == ["a", "b", "d", "c", "a_right"]

      df4 = DF.join(left, right, on: [{"a", "d"}], how: :right)

      assert DF.to_columns(df4, atom_keys: true) == %{
               a: [5, 6, 7],
               b: ["a", "b", "b"],
               c: ["d", "e", "f"],
               d: [1, 2, 2]
             }

      assert df4.names == ["d", "c", "a", "b"]
    end

    test "with a custom 'on' but with repeated column on left side" do
      left = DF.new(a: [1, 2, 3], b: ["a", "b", "c"], d: [5, 6, 7])
      right = DF.new(d: [1, 2, 2], c: ["d", "e", "f"])

      df = DF.join(left, right, on: [{"a", "d"}])

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [1, 2, 2],
               b: ["a", "b", "b"],
               c: ["d", "e", "f"],
               d: [5, 6, 6]
             }

      assert df.names == ["a", "b", "d", "c"]

      df1 = DF.join(left, right, on: [{"a", "d"}], how: :left)

      assert DF.to_columns(df1, atom_keys: true) == %{
               a: [1, 2, 2, 3],
               b: ["a", "b", "b", "c"],
               c: ["d", "e", "f", nil],
               d: [5, 6, 6, 7]
             }

      assert df1.names == ["a", "b", "d", "c"]

      df2 = DF.join(left, right, on: [{"a", "d"}], how: :outer)

      assert DF.to_columns(df2, atom_keys: true) == %{
               a: [1, 2, 2, 3],
               b: ["a", "b", "b", "c"],
               c: ["d", "e", "f", nil],
               d: [5, 6, 6, 7]
             }

      assert df2.names == ["a", "b", "d", "c"]

      df3 = DF.join(left, right, how: :cross)

      assert DF.to_columns(df3, atom_keys: true) == %{
               a: [1, 1, 1, 2, 2, 2, 3, 3, 3],
               b: ["a", "a", "a", "b", "b", "b", "c", "c", "c"],
               c: ["d", "e", "f", "d", "e", "f", "d", "e", "f"],
               d: [5, 5, 5, 6, 6, 6, 7, 7, 7],
               d_right: [1, 2, 2, 1, 2, 2, 1, 2, 2]
             }

      assert df3.names == ["a", "b", "d", "d_right", "c"]

      df4 = DF.join(left, right, on: [{"a", "d"}], how: :right)

      assert DF.to_columns(df4, atom_keys: true) == %{
               b: ["a", "b", "b"],
               c: ["d", "e", "f"],
               d: [1, 2, 2],
               d_left: [5, 6, 6]
             }

      assert df4.names == ["d", "c", "b", "d_left"]
    end

    test "with invalid join strategy" do
      left = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])
      right = DF.new(a: [1, 2, 2], c: ["d", "e", "f"])

      msg =
        "join type is not valid: :inner_join. Valid options are: :inner, :left, :right, :outer, :cross"

      assert_raise ArgumentError, msg, fn -> DF.join(left, right, how: :inner_join) end
    end

    test "with matching column indexes" do
      left = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])
      right = DF.new(a: [1, 2, 2], c: ["d", "e", "f"])

      df = DF.join(left, right, on: [0])

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [1, 2, 2],
               b: ["a", "b", "b"],
               c: ["d", "e", "f"]
             }
    end

    test "with no matching column indexes" do
      left = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])
      right = DF.new(c: ["d", "e", "f"], a: [1, 2, 2])

      msg = "the column given to option `:on` is not the same for both dataframes"

      assert_raise ArgumentError, msg, fn -> DF.join(left, right, on: [0]) end
    end
  end

  describe "from_csv/2 options" do
    @tag :tmp_dir
    test "delimiter", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a*b
        c*d
        e*f
        """)

      df = DF.from_csv!(csv, delimiter: "*")

      assert DF.to_columns(df, atom_keys: true) == %{
               a: ["c", "e"],
               b: ["d", "f"]
             }
    end

    @tag :tmp_dir
    test "dtypes", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        1,2
        3,4
        """)

      df = DF.from_csv!(csv, dtypes: [{"a", :string}])

      assert DF.to_columns(df, atom_keys: true) == %{
               a: ["1", "3"],
               b: [2, 4]
             }

      df = DF.from_csv!(csv, dtypes: %{a: :string})

      assert DF.to_columns(df, atom_keys: true) == %{
               a: ["1", "3"],
               b: [2, 4]
             }
    end

    @tag :tmp_dir
    test "dtypes - parse datetime", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b,c
        1,2,2020-10-15 00:00:01,
        3,4,2020-10-15 00:00:18
        """)

      df = DF.from_csv!(csv, parse_dates: true)
      assert %{"c" => :datetime} = Explorer.DataFrame.dtypes(df)

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [1, 3],
               b: [2, 4],
               c: [~N[2020-10-15 00:00:01.000000], ~N[2020-10-15 00:00:18.000000]]
             }
    end

    @tag :tmp_dir
    test "dtypes - do not parse datetime(default)", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b,c
        1,2,"2020-10-15 00:00:01",
        3,4,2020-10-15 00:00:18
        """)

      df = DF.from_csv!(csv, parse_dates: false)
      assert %{"c" => :string} = Explorer.DataFrame.dtypes(df)

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [1, 3],
               b: [2, 4],
               c: ["2020-10-15 00:00:01", "2020-10-15 00:00:18"]
             }
    end

    @tag :tmp_dir
    test "header", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        c,d
        e,f
        """)

      df = DF.from_csv!(csv, header: false)

      assert DF.to_columns(df, atom_keys: true) == %{
               column_1: ["a", "c", "e"],
               column_2: ["b", "d", "f"]
             }
    end

    @tag :tmp_dir
    test "max_rows", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        c,d
        e,f
        """)

      df = DF.from_csv!(csv, max_rows: 1)

      assert DF.to_columns(df, atom_keys: true) == %{
               a: ["c"],
               b: ["d"]
             }
    end

    @tag :tmp_dir
    test "null_character", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        n/a,NA
        nil,
        c,d
        """)

      df = DF.from_csv!(csv, null_character: "n/a")

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [nil, "nil", "c"],
               b: ["NA", nil, "d"]
             }
    end

    @tag :tmp_dir
    test "skip_rows", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        c,d
        e,f
        """)

      df = DF.from_csv!(csv, skip_rows: 1)

      assert DF.to_columns(df, atom_keys: true) == %{
               c: ["e"],
               d: ["f"]
             }
    end

    @tag :tmp_dir
    test "columns - str", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        c,d
        e,f
        """)

      df = DF.from_csv!(csv, columns: ["b"])

      assert DF.to_columns(df, atom_keys: true) == %{
               b: ["d", "f"]
             }
    end

    @tag :tmp_dir
    test "columns - atom", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        c,d
        e,f
        """)

      df = DF.from_csv!(csv, columns: [:b])

      assert DF.to_columns(df, atom_keys: true) == %{
               b: ["d", "f"]
             }
    end

    @tag :tmp_dir
    test "columns - integer", config do
      csv =
        tmp_csv(config.tmp_dir, """
        a,b
        c,d
        e,f
        """)

      df = DF.from_csv!(csv, columns: [1])

      assert DF.to_columns(df, atom_keys: true) == %{
               b: ["d", "f"]
             }
    end

    @tag :tmp_dir
    test "automatically detects gz and uncompresses", config do
      csv = Path.join(config.tmp_dir, "tmp.csv.gz")

      :ok =
        File.write!(
          csv,
          :zlib.gzip("""
          a,b
          1,2
          3,4
          """)
        )

      df = DF.from_csv!(csv)

      assert DF.to_columns(df, atom_keys: true) == %{
               a: [1, 3],
               b: [2, 4]
             }
    end
  end

  describe "parquet read and write" do
    @tag :tmp_dir
    test "can write parquet to file", %{df: df, tmp_dir: tmp_dir} do
      parquet_path = Path.join(tmp_dir, "test.parquet")

      assert {:ok, ^parquet_path} = DF.to_parquet(df, parquet_path)
      assert {:ok, parquet_df} = DF.from_parquet(parquet_path)

      assert DF.names(df) == DF.names(parquet_df)
      assert DF.dtypes(df) == DF.dtypes(parquet_df)
      assert DF.to_columns(df) == DF.to_columns(parquet_df)
    end

    @tag :tmp_dir
    test "can write parquet to file with compression", %{
      df: df,
      tmp_dir: tmp_dir
    } do
      for compression <- [:snappy, :gzip, :brotli, :zstd, :lz4raw] do
        parquet_path = Path.join(tmp_dir, "test.parquet")

        assert {:ok, ^parquet_path} = DF.to_parquet(df, parquet_path, compression: compression)
        assert {:ok, parquet_df} = DF.from_parquet(parquet_path)

        assert DF.names(df) == DF.names(parquet_df)
        assert DF.dtypes(df) == DF.dtypes(parquet_df)
        assert DF.to_columns(df) == DF.to_columns(parquet_df)
      end
    end

    @tag :tmp_dir
    test "can write parquet to file with compression and level", %{
      df: df,
      tmp_dir: tmp_dir
    } do
      for compression <- [:gzip, :brotli, :zstd], level <- [1, 2, 3] do
        parquet_path = Path.join(tmp_dir, "test.parquet")

        assert {:ok, ^parquet_path} =
                 DF.to_parquet(df, parquet_path, compression: {compression, level})

        assert {:ok, parquet_df} = DF.from_parquet(parquet_path)

        assert DF.names(df) == DF.names(parquet_df)
        assert DF.dtypes(df) == DF.dtypes(parquet_df)
        assert DF.to_columns(df) == DF.to_columns(parquet_df)
      end
    end
  end

  describe "from_ndjson/2" do
    @tag :tmp_dir
    test "reads from file with default options", %{tmp_dir: tmp_dir} do
      ndjson_path = to_ndjson(tmp_dir)

      assert {:ok, df} = DF.from_ndjson(ndjson_path)

      assert DF.names(df) == ~w[a b c d]
      assert DF.dtypes(df) == %{"a" => :integer, "b" => :float, "c" => :boolean, "d" => :string}

      assert take_five(df["a"]) == [1, -10, 2, 1, 7]
      assert take_five(df["b"]) == [2.0, -3.5, 0.6, 2.0, -3.5]
      assert take_five(df["c"]) == [false, true, false, false, true]
      assert take_five(df["d"]) == ["4", "4", "text", "4", "4"]

      assert {:error, _message} = DF.from_ndjson(Path.join(tmp_dir, "idontexist.ndjson"))
    end

    @tag :tmp_dir
    test "reads from file with options", %{tmp_dir: tmp_dir} do
      ndjson_path = to_ndjson(tmp_dir)

      assert {:ok, df} = DF.from_ndjson(ndjson_path, infer_schema_length: 3, batch_size: 3)

      assert DF.names(df) == ~w[a b c d]
      assert DF.dtypes(df) == %{"a" => :integer, "b" => :float, "c" => :boolean, "d" => :string}
    end

    defp to_ndjson(tmp_dir) do
      ndjson_path = Path.join(tmp_dir, "test.ndjson")

      contents = """
      {"a":1, "b":2.0, "c":false, "d":"4"}
      {"a":-10, "b":-3.5, "c":true, "d":"4"}
      {"a":2, "b":0.6, "c":false, "d":"text"}
      {"a":1, "b":2.0, "c":false, "d":"4"}
      {"a":7, "b":-3.5, "c":true, "d":"4"}
      {"a":1, "b":0.6, "c":false, "d":"text"}
      {"a":1, "b":2.0, "c":false, "d":"4"}
      {"a":5, "b":-3.5, "c":true, "d":"4"}
      {"a":1, "b":0.6, "c":false, "d":"text"}
      {"a":1, "b":2.0, "c":false, "d":"4"}
      {"a":1, "b":-3.5, "c":true, "d":"4"}
      {"a":100000000000000, "b":0.6, "c":false, "d":"text"}
      """

      :ok = File.write!(ndjson_path, contents)
      ndjson_path
    end

    defp take_five(series) do
      series |> Series.to_list() |> Enum.take(5)
    end
  end

  describe "to_ndjson" do
    @tag :tmp_dir
    test "writes to a file", %{tmp_dir: tmp_dir} do
      df =
        DF.new(
          a: [1, -10, 2, 1, 7, 1, 1, 5, 1, 1, 1, 100_000_000_000_000],
          b: [2.0, -3.5, 0.6, 2.0, -3.5, 0.6, 2.0, -3.5, 0.6, 2.0, -3.5, 0.6],
          c: [false, true, false, false, true, false, false, true, false, false, true, false],
          d: ["4", "4", "text", "4", "4", "text", "4", "4", "text", "4", "4", "text"]
        )

      ndjson_path = Path.join(tmp_dir, "test-write.ndjson")

      assert {:ok, ^ndjson_path} = DF.to_ndjson(df, ndjson_path)
      assert {:ok, ndjson_df} = DF.from_ndjson(ndjson_path)

      assert DF.names(df) == DF.names(ndjson_df)
      assert DF.dtypes(df) == DF.dtypes(ndjson_df)
      assert DF.to_columns(df) == DF.to_columns(ndjson_df)
    end
  end

  describe "table/1" do
    test "prints 5 rows by default" do
      df = Datasets.iris()

      assert capture_io(fn -> DF.table(df) end) == """
             +-----------------------------------------------------------------------+
             |              Explorer DataFrame: [rows: 150, columns: 5]              |
             +--------------+-------------+--------------+-------------+-------------+
             | sepal_length | sepal_width | petal_length | petal_width |   species   |
             |   <float>    |   <float>   |   <float>    |   <float>   |  <string>   |
             +==============+=============+==============+=============+=============+
             | 5.1          | 3.5         | 1.4          | 0.2         | Iris-setosa |
             +--------------+-------------+--------------+-------------+-------------+
             | 4.9          | 3.0         | 1.4          | 0.2         | Iris-setosa |
             +--------------+-------------+--------------+-------------+-------------+
             | 4.7          | 3.2         | 1.3          | 0.2         | Iris-setosa |
             +--------------+-------------+--------------+-------------+-------------+
             | 4.6          | 3.1         | 1.5          | 0.2         | Iris-setosa |
             +--------------+-------------+--------------+-------------+-------------+
             | 5.0          | 3.6         | 1.4          | 0.2         | Iris-setosa |
             +--------------+-------------+--------------+-------------+-------------+

             """
    end

    test "accepts limit keyword param" do
      df = Datasets.iris()

      assert capture_io(fn -> DF.table(df, limit: 1) end) == """
             +-----------------------------------------------------------------------+
             |              Explorer DataFrame: [rows: 150, columns: 5]              |
             +--------------+-------------+--------------+-------------+-------------+
             | sepal_length | sepal_width | petal_length | petal_width |   species   |
             |   <float>    |   <float>   |   <float>    |   <float>   |  <string>   |
             +==============+=============+==============+=============+=============+
             | 5.1          | 3.5         | 1.4          | 0.2         | Iris-setosa |
             +--------------+-------------+--------------+-------------+-------------+

             """
    end

    test "accepts limit: :infinity" do
      df =
        DF.new(
          a: [1, 2, 3, 4, 5, 6, 7, 8, 9],
          b: ~w[a b c d e f g h i],
          c: [9.1, 8.2, 7.3, 6.4, 5.5, 4.6, 3.7, 2.8, 1.9]
        )

      assert capture_io(fn -> DF.table(df, limit: :infinity) end) == """
             +--------------------------------------------+
             | Explorer DataFrame: [rows: 9, columns: 3]  |
             +---------------+--------------+-------------+
             |       a       |      b       |      c      |
             |   <integer>   |   <string>   |   <float>   |
             +===============+==============+=============+
             | 1             | a            | 9.1         |
             +---------------+--------------+-------------+
             | 2             | b            | 8.2         |
             +---------------+--------------+-------------+
             | 3             | c            | 7.3         |
             +---------------+--------------+-------------+
             | 4             | d            | 6.4         |
             +---------------+--------------+-------------+
             | 5             | e            | 5.5         |
             +---------------+--------------+-------------+
             | 6             | f            | 4.6         |
             +---------------+--------------+-------------+
             | 7             | g            | 3.7         |
             +---------------+--------------+-------------+
             | 8             | h            | 2.8         |
             +---------------+--------------+-------------+
             | 9             | i            | 1.9         |
             +---------------+--------------+-------------+

             """
    end
  end

  test "fetch/2" do
    df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"], c: [4.0, 5.1, 6.2])

    assert Series.to_list(df[:a]) == [1, 2, 3]
    assert Series.to_list(df["a"]) == [1, 2, 3]
    assert DF.to_columns(df[["a"]]) == %{"a" => [1, 2, 3]}
    assert DF.to_columns(df[[:a, :c]]) == %{"a" => [1, 2, 3], "c" => [4.0, 5.1, 6.2]}
    assert DF.to_columns(df[0..-2]) == %{"a" => [1, 2, 3], "b" => ["a", "b", "c"]}
    assert DF.to_columns(df[-3..-1]) == DF.to_columns(df)
    assert DF.to_columns(df[0..-1]) == DF.to_columns(df)

    assert %Series{} = s1 = df[0]
    assert Series.to_list(s1) == [1, 2, 3]

    assert %Series{} = s2 = df[2]
    assert Series.to_list(s2) == [4.0, 5.1, 6.2]

    assert %Series{} = s3 = df[-1]
    assert Series.to_list(s3) == [4.0, 5.1, 6.2]

    assert %DF{} = df2 = df[1..2]
    assert DF.names(df2) == ["b", "c"]

    assert %DF{} = df3 = df[-2..-1]
    assert DF.names(df3) == ["b", "c"]

    assert_raise ArgumentError,
                 "no column exists at index 100",
                 fn -> df[100] end

    assert_raise ArgumentError,
                 "could not find column name \"class\"",
                 fn -> df[:class] end

    assert DF.to_columns(df[0..100]) == DF.to_columns(df)
  end

  test "pop/2" do
    df1 = DF.new(a: [1, 2, 3], b: ["a", "b", "c"], c: [4.0, 5.1, 6.2])

    {s1, df2} = Access.pop(df1, "a")
    assert Series.to_list(s1) == [1, 2, 3]
    assert DF.to_columns(df2) == %{"b" => ["a", "b", "c"], "c" => [4.0, 5.1, 6.2]}

    {s1, df2} = Access.pop(df1, :a)
    assert Series.to_list(s1) == [1, 2, 3]
    assert DF.to_columns(df2) == %{"b" => ["a", "b", "c"], "c" => [4.0, 5.1, 6.2]}

    {s1, df2} = Access.pop(df1, 0)
    assert Series.to_list(s1) == [1, 2, 3]
    assert DF.to_columns(df2) == %{"b" => ["a", "b", "c"], "c" => [4.0, 5.1, 6.2]}

    {s1, df2} = Access.pop(df1, -3)
    assert Series.to_list(s1) == [1, 2, 3]
    assert DF.to_columns(df2) == %{"b" => ["a", "b", "c"], "c" => [4.0, 5.1, 6.2]}

    {df3, df4} = Access.pop(df1, ["a", "c"])
    assert DF.to_columns(df3) == %{"a" => [1, 2, 3], "c" => [4.0, 5.1, 6.2]}
    assert DF.to_columns(df4) == %{"b" => ["a", "b", "c"]}

    {df3, df4} = Access.pop(df1, 0..1)
    assert DF.to_columns(df3) == %{"a" => [1, 2, 3], "b" => ["a", "b", "c"]}
    assert DF.to_columns(df4) == %{"c" => [4.0, 5.1, 6.2]}

    {df3, df4} = Access.pop(df1, 0..-2)
    assert DF.to_columns(df3) == %{"a" => [1, 2, 3], "b" => ["a", "b", "c"]}
    assert DF.to_columns(df4) == %{"c" => [4.0, 5.1, 6.2]}

    assert {%Series{} = s2, %DF{} = df5} = Access.pop(df1, :a)
    assert Series.to_list(s2) == Series.to_list(df1[:a])
    assert DF.names(df1) -- DF.names(df5) == ["a"]

    assert {%Series{} = s3, %DF{} = df6} = Access.pop(df1, 0)
    assert Series.to_list(s3) == Series.to_list(df1[:a])
    assert DF.names(df1) -- DF.names(df6) == ["a"]
  end

  test "get_and_update/3" do
    df1 = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

    {s, df2} =
      Access.get_and_update(df1, "a", fn current_value ->
        {current_value, [0, 0, 0]}
      end)

    assert Series.to_list(s) == [1, 2, 3]
    assert DF.to_columns(df2, atom_keys: true) == %{a: [0, 0, 0], b: ["a", "b", "c"]}
  end

  test "concat_rows/2" do
    df1 = DF.new(x: [1, 2, 3], y: ["a", "b", "c"])
    df2 = DF.new(x: [4, 5, 6], y: ["d", "e", "f"])
    df3 = DF.concat_rows(df1, df2)

    assert Series.to_list(df3["x"]) == [1, 2, 3, 4, 5, 6]
    assert Series.to_list(df3["y"]) == ~w(a b c d e f)

    df2 = DF.new(x: [4.0, 5.0, 6.0], y: ["d", "e", "f"])
    df3 = DF.concat_rows(df1, df2)

    assert Series.to_list(df3["x"]) == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

    df4 = DF.new(x: [7, 8, 9], y: ["g", "h", nil])
    df5 = DF.concat_rows(df3, df4)

    assert Series.to_list(df5["x"]) == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
    assert Series.to_list(df5["y"]) == ~w(a b c d e f g h) ++ [nil]

    df6 = DF.concat_rows([df1, df2, df4])

    assert Series.to_list(df6["x"]) == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
    assert Series.to_list(df6["y"]) == ~w(a b c d e f g h) ++ [nil]

    assert_raise ArgumentError,
                 "dataframes must have the same columns",
                 fn -> DF.concat_rows(df1, DF.new(z: [7, 8, 9])) end

    assert_raise ArgumentError,
                 "dataframes must have the same columns",
                 fn -> DF.concat_rows(df1, DF.new(x: [7, 8, 9], z: [7, 8, 9])) end

    assert_raise ArgumentError,
                 "columns and dtypes must be identical for all dataframes",
                 fn -> DF.concat_rows(df1, DF.new(x: [7, 8, 9], y: [10, 11, 12])) end
  end

  describe "distinct/2" do
    test "with lists", %{df: df} do
      df1 = DF.distinct(df, columns: [:year, :country])
      assert DF.names(df1) == ["year", "country"]

      assert DF.shape(df1) == {1094, 2}

      df1 = DF.distinct(df, columns: [0, 1])
      assert DF.names(df1) == ["year", "country"]

      assert df == DF.distinct(df, columns: [])

      df2 = DF.distinct(df, columns: [:year, :country], keep_all?: true)
      assert DF.names(df2) == DF.names(df)
    end

    test "with one column", %{df: df} do
      df1 = DF.distinct(df, columns: [:country])
      assert DF.names(df1) == ["country"]

      assert DF.shape(df1) == {222, 1}
    end

    test "with ranges", %{df: df} do
      df1 = DF.distinct(df, columns: 0..1)
      assert DF.names(df1) == ["year", "country"]

      df2 = DF.distinct(df)
      assert DF.names(df2) == DF.names(df)

      df3 = DF.distinct(df, columns: 0..-1)
      assert DF.names(df3) == DF.names(df)

      assert df == DF.distinct(df, columns: 100..200)
    end
  end

  test "drop_nil/2" do
    df = DF.new(a: [1, 2, nil], b: [1, nil, 3])

    df1 = DF.drop_nil(df)
    assert DF.to_columns(df1) == %{"a" => [1], "b" => [1]}

    df2 = DF.drop_nil(df, :a)
    assert DF.to_columns(df2) == %{"a" => [1, 2], "b" => [1, nil]}

    # Empty list do nothing.
    df3 = DF.drop_nil(df, [])
    assert DF.to_columns(df3) == %{"a" => [1, 2, nil], "b" => [1, nil, 3]}

    assert_raise ArgumentError,
                 "no column exists at index 3",
                 fn -> DF.drop_nil(df, [3, 4, 5]) end

    # It takes the slice of columns in the range
    df4 = DF.drop_nil(df, 0..200)
    assert DF.to_columns(df4) == %{"a" => [1], "b" => [1]}
  end

  describe "rename/2" do
    test "with lists" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

      df1 = DF.rename(df, ["c", "d"])

      assert DF.names(df1) == ["c", "d"]
      assert df1.names == ["c", "d"]
      assert Series.to_list(df1["c"]) == Series.to_list(df["a"])
    end

    test "with keyword" do
      df = DF.new(a: ["a", "b", "a"], b: [1, 3, 1])
      df1 = DF.rename(df, a: "first")

      assert df1.names == ["first", "b"]
      assert Series.to_list(df1["first"]) == Series.to_list(df["a"])
    end

    test "with a map" do
      df = DF.new(a: ["a", "b", "a"], b: [1, 3, 1])
      df1 = DF.rename(df, %{"a" => "first", "b" => "second"})

      assert df1.names == ["first", "second"]
      assert Series.to_list(df1["first"]) == Series.to_list(df["a"])
      assert Series.to_list(df1["second"]) == Series.to_list(df["b"])
    end

    test "with keyword and a column that doesn't exist" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

      assert_raise ArgumentError, "could not find column name \"g\"", fn ->
        DF.rename(df, g: "first")
      end
    end

    test "with a map and a column that doesn't exist" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

      assert_raise ArgumentError, "could not find column name \"i\"", fn ->
        DF.rename(df, %{"a" => "first", "i" => "foo"})
      end
    end

    test "with a mismatch size of columns" do
      df = DF.new(a: [1, 2, 3], b: ["a", "b", "c"])

      assert_raise ArgumentError,
                   "list of new names must match the number of columns in the dataframe; found 3 new name(s), but the supplied dataframe has 2 column(s)",
                   fn ->
                     DF.rename(df, ["first", "second", "third"])
                   end
    end
  end

  describe "rename_with/2" do
    test "with lists", %{df: df} do
      df_names = DF.names(df)

      df1 = DF.rename_with(df, ["total", "cement"], &String.upcase/1)
      df1_names = DF.names(df1)

      assert df_names -- df1_names == ["total", "cement"]
      assert df1_names -- df_names == ["TOTAL", "CEMENT"]

      assert df1.names == [
               "year",
               "country",
               "TOTAL",
               "solid_fuel",
               "liquid_fuel",
               "gas_fuel",
               "CEMENT",
               "gas_flaring",
               "per_capita",
               "bunker_fuels"
             ]
    end

    test "with ranges", %{df: df} do
      df_names = DF.names(df)

      df1 = DF.rename_with(df, 0..1, &String.upcase/1)
      df1_names = DF.names(df1)

      assert df_names -- df1_names == ["year", "country"]
      assert df1_names -- df_names == ["YEAR", "COUNTRY"]

      df2 = DF.rename_with(df, &String.upcase/1)

      assert Enum.all?(DF.names(df2), &String.match?(&1, ~r/[A-Z]+/))
    end

    test "with a filter function", %{df: df} do
      df_names = DF.names(df)

      df1 = DF.rename_with(df, &String.starts_with?(&1, "tot"), &String.upcase/1)
      df1_names = DF.names(df1)

      assert df_names -- df1_names == ["total"]
      assert df1_names -- df_names == ["TOTAL"]

      df2 = DF.rename_with(df, &String.starts_with?(&1, "non-existent"), &String.upcase/1)

      assert df2 == df
    end
  end

  describe "pivot_wider/4" do
    test "with a single id" do
      df1 = DF.new(id: [1, 1], variable: ["a", "b"], value: [1, 2])

      df2 = DF.pivot_wider(df1, "variable", "value")

      assert DF.to_columns(df2, atom_keys: true) == %{
               id: [1],
               a: [1],
               b: [2]
             }

      df3 = DF.new(id: [1, 1], variable: ["1", "2"], value: [1.0, 2.0])

      df4 =
        DF.pivot_wider(df3, "variable", "value",
          id_columns: ["id"],
          names_prefix: "column_"
        )

      assert DF.to_columns(
               df4,
               atom_keys: true
             ) == %{id: [1], column_1: [1.0], column_2: [2.0]}

      assert df4.names == ["id", "column_1", "column_2"]
    end

    test "with multiple id columns" do
      df = DF.new(id: [1, 1], variable: ["a", "b"], value: [1, 2], other_id: [4, 5])
      df1 = DF.pivot_wider(df, "variable", "value")

      assert DF.names(df1) == ["id", "other_id", "a", "b"]
      assert df1.names == ["id", "other_id", "a", "b"]

      assert DF.to_columns(df1, atom_keys: true) == %{
               id: [1, 1],
               other_id: [4, 5],
               a: [1, nil],
               b: [nil, 2]
             }
    end

    test "with a single id column ignoring other columns" do
      df = DF.new(id: [1, 1], variable: ["a", "b"], value: [1, 2], other: [4, 5])

      df2 = DF.pivot_wider(df, "variable", "value", id_columns: [:id])
      assert DF.names(df2) == ["id", "a", "b"]

      df2 = DF.pivot_wider(df, "variable", "value", id_columns: [0])
      assert DF.names(df2) == ["id", "a", "b"]
      assert df2.names == ["id", "a", "b"]

      assert DF.to_columns(df2, atom_keys: true) == %{
               id: [1],
               a: [1],
               b: [2]
             }
    end

    test "with a single id column and repeated values" do
      df = DF.new(id: [1, 1, 2, 2], variable: ["a", "b", "a", "b"], value: [1, 2, 3, 4])

      df2 = DF.pivot_wider(df, "variable", "value", id_columns: [:id])
      assert DF.names(df2) == ["id", "a", "b"]

      df2 = DF.pivot_wider(df, "variable", "value", id_columns: [0])
      assert DF.names(df2) == ["id", "a", "b"]

      assert DF.to_columns(df2, atom_keys: true) == %{
               id: [1, 2],
               a: [1, 3],
               b: [2, 4]
             }
    end

    test "with a filter function for id columns" do
      df = DF.new(id_main: [1, 1], variable: ["a", "b"], value: [1, 2], other: [4, 5])

      df1 = DF.pivot_wider(df, "variable", "value", id_columns: &String.starts_with?(&1, "id"))
      assert DF.names(df1) == ["id_main", "a", "b"]

      assert DF.to_columns(df1, atom_keys: true) == %{
               id_main: [1],
               a: [1],
               b: [2]
             }
    end

    test "without an id column" do
      df = DF.new(id: [1, 1], variable: ["a", "b"], value: [1, 2], other_id: [4, 5])

      assert_raise ArgumentError,
                   "id_columns must select at least one existing column, but [] selects none",
                   fn ->
                     DF.pivot_wider(df, "variable", "value", id_columns: [])
                   end

      assert_raise ArgumentError,
                   ~r/id_columns must select at least one existing column, but/,
                   fn ->
                     DF.pivot_wider(df, "variable", "value",
                       id_columns: &String.starts_with?(&1, "none")
                     )
                   end
    end
  end

  describe "pivot_longer/3" do
    test "without keeping columns", %{df: df} do
      df = DF.pivot_longer(df, &String.ends_with?(&1, "fuel"), keep: [])

      assert df.names == ["variable", "value"]
      assert df.dtypes == %{"variable" => :string, "value" => :integer}
      assert DF.shape(df) == {3282, 2}
    end

    test "keeping some columns", %{df: df} do
      df = DF.pivot_longer(df, &String.ends_with?(&1, "fuel"), keep: ["year", "country"])

      assert df.names == ["year", "country", "variable", "value"]

      assert df.dtypes == %{
               "year" => :integer,
               "country" => :string,
               "variable" => :string,
               "value" => :integer
             }

      assert DF.shape(df) == {3282, 4}
    end

    test "keeping all the columns (not passing keep option)", %{df: df} do
      df = DF.pivot_longer(df, &String.ends_with?(&1, ["fuel", "fuels"]))

      assert df.names == [
               "year",
               "country",
               "total",
               "cement",
               "gas_flaring",
               "per_capita",
               "variable",
               "value"
             ]

      assert DF.shape(df) == {4376, 8}
    end

    test "dropping some columns", %{df: df} do
      df =
        DF.pivot_longer(df, &String.ends_with?(&1, ["fuel", "fuels"]),
          drop: ["gas_flaring", "cement"]
        )

      assert df.names == [
               "year",
               "country",
               "total",
               "per_capita",
               "variable",
               "value"
             ]
    end

    test "keep and drop with the same columns drops the columns", %{df: df} do
      df =
        DF.pivot_longer(df, &String.ends_with?(&1, ["fuel", "fuels"]),
          keep: ["gas_flaring", "cement"],
          drop: fn name -> name == "cement" end
        )

      assert df.names == [
               "gas_flaring",
               "variable",
               "value"
             ]
    end

    test "with pivot column in the same list of keep columns", %{df: df} do
      assert_raise ArgumentError,
                   "columns to keep must not include columns to pivot, but found \"solid_fuel\" in both",
                   fn ->
                     DF.pivot_longer(df, &String.ends_with?(&1, "fuel"),
                       keep: ["year", "country", "solid_fuel"]
                     )
                   end
    end

    test "with multiple types of columns to pivot", %{df: df} do
      assert_raise ArgumentError,
                   "columns to pivot must include columns with the same dtype, but found multiple dtypes: [:string, :integer]",
                   fn ->
                     DF.pivot_longer(df, &(&1 in ["solid_fuel", "country"]))
                   end
    end
  end

  test "table reader integration" do
    df = DF.new(x: [1, 2, 3], y: ["a", "b", "c"])

    assert df |> Table.to_rows() |> Enum.to_list() == [
             %{"x" => 1, "y" => "a"},
             %{"x" => 2, "y" => "b"},
             %{"x" => 3, "y" => "c"}
           ]

    columns = Table.to_columns(df)
    assert Enum.to_list(columns["x"]) == [1, 2, 3]
    assert Enum.to_list(columns["y"]) == ["a", "b", "c"]

    assert {:columns, %{count: 3}, _} = Table.Reader.init(df)
  end

  test "collect/1 is no-op", %{df: df} do
    assert DF.collect(df) == df
  end

  test "to_lazy/1", %{df: df} do
    assert %Explorer.PolarsBackend.LazyDataFrame{} = DF.to_lazy(df).data
  end

  describe "select/3" do
    test "keep column names" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3])
      df = DF.select(df, ["a"])

      assert DF.names(df) == ["a"]
      assert df.names == ["a"]
    end

    test "keep column positions" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3])
      df = DF.select(df, [1])

      assert DF.names(df) == ["b"]
      assert df.names == ["b"]
    end

    test "keep column range" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3], c: [42.0, 42.1, 42.2])
      df = DF.select(df, 1..2)

      assert DF.names(df) == ["b", "c"]
      assert df.names == ["b", "c"]
    end

    test "keep columns matching callback" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3], c: [42.0, 42.1, 42.2])
      df = DF.select(df, fn name -> name in ~w(a c) end)

      assert DF.names(df) == ["a", "c"]
      assert df.names == ["a", "c"]
    end

    test "keep column raises error with non-existent column" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3])

      assert_raise ArgumentError, "could not find column name \"g\"", fn ->
        DF.select(df, ["g"])
      end
    end

    test "drop column names" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3])
      df = DF.select(df, ["a"], :drop)

      assert DF.names(df) == ["b"]
      assert df.names == ["b"]
    end

    test "drop column positions" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3])
      df = DF.select(df, [1], :drop)

      assert DF.names(df) == ["a"]
      assert df.names == ["a"]
    end

    test "drop column range" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3], c: [42.0, 42.1, 42.2])
      df = DF.select(df, 1..2, :drop)

      assert DF.names(df) == ["a"]
      assert df.names == ["a"]
    end

    test "drop columns matching callback" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3], c: [42.0, 42.1, 42.2])
      df = DF.select(df, fn name -> name in ~w(a c) end, :drop)

      assert DF.names(df) == ["b"]
      assert df.names == ["b"]
    end

    test "drop column raises error with non-existent column" do
      df = DF.new(a: ["a", "b", "c"], b: [1, 2, 3])

      assert_raise ArgumentError, "could not find column name \"g\"", fn ->
        DF.select(df, ["g"], :drop)
      end
    end
  end
end
