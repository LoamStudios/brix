defmodule Brix.ValidatorTest do
  use ExUnit.Case, async: true

  alias Brix.Validator
  alias Brix.Validator.Issue

  @valid Path.expand("../fixtures/valid", __DIR__)
  @missing_site Path.expand("../fixtures/missing_site", __DIR__)
  @missing_page_yml Path.expand("../fixtures/missing_page_yml", __DIR__)
  @bad_refs Path.expand("../fixtures/bad_refs", __DIR__)

  describe "Issue struct" do
    test "creates with all fields" do
      issue = %Issue{
        path: "pages/about/page.yml",
        severity: :error,
        type: :missing_file,
        message: "site.yml not found"
      }

      assert issue.severity == :error
      assert issue.type == :missing_file
    end
  end

  describe "validate/1 with valid content" do
    test "returns no errors and no warnings" do
      result = Validator.validate(@valid)

      assert result.errors == []
      assert result.warnings == []
    end
  end

  describe "structural checks" do
    test "errors when site.yml is missing" do
      result = Validator.validate(@missing_site)

      assert has_error?(result, :missing_file, ~r/site\.yml/)
    end

    test "errors when page directory has no page.yml" do
      result = Validator.validate(@missing_page_yml)

      assert has_error?(result, :missing_file, ~r/page\.yml/)
    end
  end

  describe "referential integrity" do
    test "errors when page references nonexistent layout" do
      result = Validator.validate(@bad_refs)

      assert has_error?(result, :unresolved_reference, ~r/layout "nonexistent_layout" not found/)
    end

    test "errors when page references nonexistent author" do
      result = Validator.validate(@bad_refs)

      assert has_error?(result, :unresolved_reference, ~r/author "ghost" not found/)
    end

    test "does not error for valid author reference" do
      result = Validator.validate(@bad_refs)

      refute has_error?(result, :unresolved_reference, ~r/author "jeff" not found/)
    end

    test "errors when page references nonexistent tag" do
      result = Validator.validate(@bad_refs)

      assert has_error?(result, :unresolved_reference, ~r/tag "missing_tag" not found/)
    end

    test "does not error for valid tag reference" do
      result = Validator.validate(@bad_refs)

      refute has_error?(result, :unresolved_reference, ~r/tag "elixir" not found/)
    end

    test "errors when section references nonexistent template" do
      result = Validator.validate(@bad_refs)

      assert has_error?(result, :unresolved_reference, ~r/template "nonexistent_template" not found/)
    end

    test "errors when layout section references nonexistent template" do
      result = Validator.validate(@bad_refs)

      assert has_error?(result, :unresolved_reference, ~r/template "nav" not found/)
    end

    test "errors when media file is missing on disk" do
      result = Validator.validate(@bad_refs)

      assert has_error?(result, :missing_file, ~r/files\/missing\.jpg.*not found on disk/)
    end

    test "errors when author avatar references nonexistent media" do
      result = Validator.validate(@bad_refs)

      assert has_error?(result, :unresolved_reference, ~r/avatar.*"nonexistent_avatar" not found/)
    end
  end

  # --- Helpers ---

  defp has_error?(result, type, message_pattern) do
    Enum.any?(result.errors, fn issue ->
      issue.type == type and Regex.match?(message_pattern, issue.message)
    end)
  end
end
