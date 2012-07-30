defmodule DocTest.Test do
  use ExUnit.Case, async: true
  defp tmp_file(dir) do
    # since now() produces unique value following should work
    {a, b, c} = :erlang.now
    dir <> "/" <> atom_to_binary(node) <> "-#{inspect a}.#{inspect b}.#{inspect c}"
  end
  defmacro stdout([{:do, block}]) do
    file = tmp_file("/tmp")
    quote do
      current = :erlang.group_leader
      { :ok, stdio} = File.open unquote(file), [:write]
      :erlang.group_leader stdio, self()
      unquote(block)
      :erlang.group_leader current, self()
      :ok = File.close stdio
      {:ok, body} = File.read unquote(file)
      File.rm unquote(file)
      body
    end
  end

  defmacro test_module([{:do, block}]) do
    quote do
      stdout do
        defmodule T do
          use DocTest
          unquote(block)
        end
        :code.delete(T)
        :code.purge(T)
      end
    end
  end

  def report(result) do
    target = DocTest.Test.T
    {pass, fail} = Enum.reduce binary_to_list(result), {0, 0},
       (fn(char, {pass, fail}) ->
          case <<char>> do
            "." -> {pass + 1, fail}
            "F" -> {pass, fail + 1}
          end
       end)
"
Testing '#{inspect target}':
#{result}
#{pass} passed and #{fail} failed."
  end
  defp compare(expected, got) do
    expected = report(expected)
    result = size(expected) == :binary.longest_common_prefix([expected, got])
    if not result, do: IO.puts got
    result
  end

  test "passing doctest" do
    spec = test_module do
       @doctest """
       # single doctest
       iex> __MODULE__.sum(1, 2)
       3
       """
       def sum(a, b) do
         a + b
       end
    end

    assert compare(".", spec)
  end

  test "failing doctest" do
    spec = test_module do
       @doctest """
       # single doctest
       iex> __MODULE__.sum(1, 2)
       5
       """
       def sum(a, b) do
         a + b
       end
    end

    assert compare("F", spec)
  end

  test "two doctests in single module" do
    spec = test_module do
       @doctest """
       # single doctest
       iex> DocTest.Test.T.sum1(1, 2)
       3
       """
       def sum1(a, b) do
         a + b
       end

       @doctest """
       # single doctest without explicit module
       iex> __MODULE__.sum2(1, 2)
       3
       """
       def sum2(a, b) do
         a + b
       end
    end

    assert compare("..", spec)
  end

end