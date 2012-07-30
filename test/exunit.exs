defmodule ExUnit.Helper do
  def files do
    :filelib.fold_files("test", ".*\\.exs\$", true,
       fn(file, acc) -> [file|acc] end, [])
  end
  def run do
    ExUnit.start []
    lc file inlist files, file != __FILE__, do: Code.require_file(file)
    ExUnit.run
  end
end

ExUnit.Helper.run

