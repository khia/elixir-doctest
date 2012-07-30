defmodule DocTest do
  defmacro __using__(_) do
    target = __CALLER__.module
    if testing?(target) do
      Module.register_attribute target, :doctest,
           accumulate: true, persist: false
      Module.register_attribute target, :__caller__, persist: false
      Module.add_attribute(target, :__caller__, __CALLER__)
      Module.add_attribute(target, :before_compile, {__MODULE__, :__before__})
      Module.add_attribute(target, :after_compile, {__MODULE__, :__after__})
    end
  end
  defp testing?(target) do
    List.member?(:init.get_plain_arguments, '+doctest')
  end
  defmacro __before__(target) do
    data = Module.read_attribute target, :doctest
    parsed = parse_doctests(target, data)
    Module.delete_attribute(target, :doctest)
    Module.add_attribute(target, :doctest, parsed)
  end
  defmacro __after__(target, _bin) do
    [caller] = Module.read_attribute target, :__caller__
    Module.delete_attribute(target, :__caller__)
    IO.puts ""
    IO.puts "Testing '#{inspect target}':"
    {errors, pass, fail} = test(caller)
    IO.puts ""
    report(errors, pass, fail)
  end

  def test(caller) do
    parsed = Module.read_attribute caller.module, :doctest
    Enum.reduce List.flatten(parsed), {[], 0, 0},
               fn({idx, lines, result}, {acc, pass, fail}) ->
                  case eval(caller, idx, lines, result) do
                   {:error, _, lines} = error -> {[error|acc], pass, fail + 1}
                   _ -> {acc, pass + 1, fail}
                 end
               end
  end

  defp report(errors, pass, fail) do
    IO.puts "#{pass} passed and #{fail} failed."
    if fail != 0 do
      lc error inlist errors do
        {:error, reason, {lines, expected, result}} = error
        lines = lc line inlist lines, do: "  " <> line
        if reason == :assert do
           reason = "Expected #{inspect result} to be equal to (==) #{inspect expected}"
        end
        IO.puts """
Failed example:
#{lines}
Expected:
  #{inspect expected}
Got:
  #{inspect result}
Reason:
  #{inspect reason}
"""
      end
    end
  end

  defp eval(caller, _idx, lines, expected) do
    try do
      {:ok, ast} = Code.string_to_ast lines
      {res, []} = Module.eval_quoted caller, ast
      if expected == list_to_binary(:io_lib.format("~p", [res])) do
        IO.write "."
      else
        IO.write "F"
        {:error, :assert, {lines, expected, res}}
      end
    catch
      kind, reason ->
        IO.write "F"
        {:error, reason, {lines, expected, nil}}
    end
  end

  defp parse_doctests(target, nil), do: []
  defp parse_doctests(target, tests) do
     lc x inlist tests do
       parse_doctest(target, :binary.split(x, ["\n"], [:global]))
     end
  end
  # [{idx, lines, result}]
  defp parse_doctest(_target, lines) do
     parse_doctest(_target, lines, 1, [], [])
  end
  defp parse_doctest(_target, [], _idx, _acc, tests) do
     List.reverse tests
  end
  defp parse_doctest(_target, [<<"iex> ", line|:binary>>|lines], idx, acc, tests) do
     parse_doctest(_target, lines, idx, [line|acc], tests)
  end
  defp parse_doctest(_target, [<<"...> ", line|:binary>>|lines], idx, acc, tests) do
     parse_doctest(_target, lines, idx, [line|acc], tests)
  end
  defp parse_doctest(_target, [""|lines], idx, acc, tests) do
     parse_doctest(_target, lines, idx, acc, tests)
  end
  defp parse_doctest(_target, [_line|lines], idx, [], tests) do
     parse_doctest(_target, lines, idx + 1, [], tests)
  end
  defp parse_doctest(_target, [line|lines], idx, acc, tests) do
     parse_doctest(_target, lines, idx + 1, [], [{idx, acc, line}|tests])
  end

end