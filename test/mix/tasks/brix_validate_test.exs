defmodule Mix.Tasks.Brix.ValidateTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @valid Path.expand("../../fixtures/valid", __DIR__)
  @bad_refs Path.expand("../../fixtures/bad_refs", __DIR__)

  test "prints success for valid content" do
    output =
      capture_io(fn ->
        Mix.Tasks.Brix.Validate.run([@valid])
      end)

    assert output =~ "Valid. 0 errors, 0 warnings."
  end

  test "prints errors and exits for invalid content" do
    output =
      capture_io(:stderr, fn ->
        assert catch_exit(Mix.Tasks.Brix.Validate.run([@bad_refs])) == {:shutdown, 1}
      end)

    assert output =~ "error:"
    assert output =~ "not found"
  end

  test "exits for nonexistent directory" do
    capture_io(:stderr, fn ->
      assert catch_exit(Mix.Tasks.Brix.Validate.run(["/nonexistent"])) == {:shutdown, 1}
    end)
  end
end
