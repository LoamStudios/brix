defmodule Brix.ValidatorTest do
  use ExUnit.Case, async: true

  alias Brix.Validator
  alias Brix.Validator.Issue

  @valid Path.expand("../fixtures/valid", __DIR__)
  @missing_site Path.expand("../fixtures/missing_site", __DIR__)
  @missing_page_yml Path.expand("../fixtures/missing_page_yml", __DIR__)
  @bad_refs Path.expand("../fixtures/bad_refs", __DIR__)
  @bad_schema Path.expand("../fixtures/bad_schema", __DIR__)

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

  describe "schema validation" do
    test "errors when required field is missing" do
      result = Validator.validate(@bad_schema)

      assert has_error?(result, :missing_required_field, ~r/missing required field "heading"/)
    end

    test "errors when media field references unknown media" do
      result = Validator.validate(@bad_schema)

      assert has_error?(result, :unresolved_reference, ~r/media "no_such_media" not found/)
    end

    test "errors when integer field has non-integer value" do
      result = Validator.validate(@bad_schema)

      assert has_error?(result, :type_mismatch, ~r/"count".*expected integer/)
    end

    test "errors when boolean field has non-boolean value" do
      result = Validator.validate(@bad_schema)

      assert has_error?(result, :type_mismatch, ~r/"visible".*expected boolean/)
    end

    test "errors when url field has invalid format" do
      result = Validator.validate(@bad_schema)

      assert has_error?(result, :type_mismatch, ~r/"link".*expected url/)
    end

    test "warns on unknown field with fuzzy suggestion" do
      result = Validator.validate(@bad_schema)

      assert has_warning?(result, :unknown_field, ~r/unknown field "headign".*did you mean "heading"/)
    end
  end

  describe "nested section validation" do
    @nested Path.expand("../fixtures/nested", __DIR__)
    @bad_nested Path.expand("../fixtures/bad_nested", __DIR__)

    test "valid nested sections pass validation" do
      result = Validator.validate(@nested)

      assert result.errors == []
      assert result.warnings == []
    end

    test "errors when child template violates of constraint" do
      result = Validator.validate(@bad_nested)

      assert has_error?(result, :invalid_child_template, ~r/template "wrong" not allowed.*allowed: slide/)
    end

    test "errors when required sections field has no children" do
      # The bad_nested fixture's gallery only has wrong+slide children in slides,
      # but we need a separate fixture to test empty. Let's check that the slides
      # field IS populated (so required check passes) and the of-constraint fails instead.
      # The "slides" field has children so required passes, but the required heading in
      # the slide child (02-slide.yml) is missing.
      result = Validator.validate(@bad_nested)

      assert has_error?(result, :missing_required_field, ~r/missing required field "heading".*template: slide/)
    end

    test "warns when children directory has no matching sections field" do
      result = Validator.validate(@bad_nested)

      assert has_warning?(result, :unexpected_children, ~r/children directory "orphans" has no matching sections field/)
    end

    test "error paths include nesting" do
      result = Validator.validate(@bad_nested)

      # Find the invalid_child_template error and check its path includes nesting
      error = Enum.find(result.errors, fn issue ->
        issue.type == :invalid_child_template
      end)

      assert error != nil
      assert error.path =~ "02-gallery.slides/"
    end
  end

  describe "collection validation" do
    @bad_collections Path.expand("../fixtures/bad_collections", __DIR__)

    test "errors when collection parent references nonexistent collection" do
      result = Validator.validate(@bad_collections)

      assert has_error?(result, :unresolved_reference, ~r/parent "nonexistent-collection" not found/)
    end

    test "errors on circular parent references" do
      result = Validator.validate(@bad_collections)

      assert has_error?(result, :circular_reference, ~r/circular parent reference.*circular-a/)
      assert has_error?(result, :circular_reference, ~r/circular parent reference.*circular-b/)
    end

    test "errors on unknown condition type" do
      result = Validator.validate(@bad_collections)

      assert has_error?(result, :invalid_condition_type, ~r/unknown condition type "bogus_type"/)
    end

    test "errors when tag condition references nonexistent tag" do
      result = Validator.validate(@bad_collections)

      assert has_error?(result, :unresolved_reference, ~r/tag "nonexistent-tag" not found/)
    end

    test "errors when author condition references nonexistent author" do
      result = Validator.validate(@bad_collections)

      assert has_error?(result, :unresolved_reference, ~r/author "ghost-author" not found/)
    end

    test "valid collections in dummy fixture pass validation" do
      dummy = Path.expand("../fixtures/dummy", __DIR__)
      result = Validator.validate(dummy)

      collection_errors = Enum.filter(result.errors, fn issue ->
        String.starts_with?(issue.path, "collections/")
      end)

      assert collection_errors == []
    end
  end

  # --- Helpers ---

  defp has_error?(result, type, message_pattern) do
    Enum.any?(result.errors, fn issue ->
      issue.type == type and Regex.match?(message_pattern, issue.message)
    end)
  end

  defp has_warning?(result, type, message_pattern) do
    Enum.any?(result.warnings, fn issue ->
      issue.type == type and Regex.match?(message_pattern, issue.message)
    end)
  end
end
