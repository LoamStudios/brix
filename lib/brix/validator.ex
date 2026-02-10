defmodule Brix.Validator do
  @moduledoc """
  Validates a content directory against structural rules, referential integrity,
  and section template schemas. Returns errors (block loading) and warnings (don't block).
  """

  alias Brix.Validator.Issue
  alias Brix.Reader

  @type result :: %{errors: [Issue.t()], warnings: [Issue.t()]}

  @doc """
  Validates the content tree at `content_dir`. Returns `%{errors: [], warnings: []}`.
  An empty `errors` list means the content is safe to load.
  """
  @spec validate(String.t()) :: result()
  def validate(content_dir) do
    # Build an index of all known slugs for reference checking
    index = build_index(content_dir)

    templates = Reader.read_section_templates(content_dir)
    templates_by_name = Map.new(templates, &{&1.name, &1})

    %{errors: [], warnings: []}
    |> check_structure(content_dir)
    |> check_references(content_dir, index)
    |> check_schemas(content_dir, index, templates_by_name)
  end

  # --- Index ---

  defp build_index(content_dir) do
    %{
      layouts: read_slugs(content_dir, "layouts/*.yml"),
      authors: read_slugs(content_dir, "authors/*.yml"),
      tags: read_slugs(content_dir, "tags/*.yml"),
      media: read_slugs(content_dir, "media/*.yml"),
      section_templates: read_slugs(content_dir, "templates/sections/*.yml")
    }
  end

  defp read_slugs(content_dir, glob) do
    content_dir
    |> Path.join(glob)
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".yml"))
    |> MapSet.new()
  end

  # --- Structural checks ---

  defp check_structure(result, content_dir) do
    result
    |> check_site_exists(content_dir)
    |> check_page_dirs(content_dir)
  end

  defp check_site_exists(result, content_dir) do
    path = Path.join(content_dir, "site.yml")

    if File.exists?(path) do
      result
    else
      add_error(result, "site.yml", :missing_file, "site.yml not found")
    end
  end

  defp check_page_dirs(result, content_dir) do
    pages_dir = Path.join(content_dir, "pages")

    if File.dir?(pages_dir) do
      pages_dir
      |> find_section_dirs()
      |> Enum.reduce(result, fn dir, acc ->
        page_yml = Path.join(Path.dirname(dir), "page.yml")

        if File.exists?(page_yml) do
          acc
        else
          relative = Path.relative_to(Path.dirname(dir), content_dir)
          add_error(acc, relative, :missing_file, "page.yml not found in #{relative}")
        end
      end)
    else
      result
    end
  end

  defp find_section_dirs(pages_dir) do
    pages_dir
    |> Path.join("**/sections")
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
  end

  # --- Referential integrity ---

  defp check_references(result, content_dir, index) do
    result
    |> check_page_references(content_dir, index)
    |> check_section_references(content_dir, index)
    |> check_layout_references(content_dir, index)
    |> check_media_files(content_dir)
    |> check_author_avatars(content_dir, index)
  end

  defp check_page_references(result, content_dir, index) do
    Reader.read_pages(content_dir)
    |> Enum.reduce(result, fn page, acc ->
      page_path = page_yml_path(page, content_dir)

      acc
      |> check_ref(page_path, :layout, page.layout, index.layouts)
      |> check_list_refs(page_path, :author, page.authors, index.authors)
      |> check_list_refs(page_path, :tag, page.tags, index.tags)
    end)
  end

  defp check_section_references(result, content_dir, index) do
    Reader.read_pages(content_dir)
    |> Enum.reduce(result, fn page, acc ->
      Enum.reduce(page.sections, acc, fn section, inner_acc ->
        section_path = section_file_path(page, section, content_dir)

        check_ref(inner_acc, section_path, :template, section.template, index.section_templates)
      end)
    end)
  end

  defp check_layout_references(result, content_dir, index) do
    Reader.read_layouts(content_dir)
    |> Enum.reduce(result, fn layout, acc ->
      layout_path = "layouts/#{layout.name}.yml"
      all_sections = layout.header_sections ++ layout.footer_sections

      Enum.reduce(all_sections, acc, fn section, inner_acc ->
        check_ref(inner_acc, layout_path, :template, section.template, index.section_templates)
      end)
    end)
  end

  defp check_media_files(result, content_dir) do
    Reader.read_media(content_dir)
    |> Enum.reduce(result, fn media, acc ->
      if media.path do
        full_path = Path.join([content_dir, "media", media.path])

        if File.exists?(full_path) do
          acc
        else
          add_error(
            acc,
            "media/#{media.slug}.yml",
            :missing_file,
            "#{media.path} not found on disk"
          )
        end
      else
        acc
      end
    end)
  end

  defp check_author_avatars(result, content_dir, index) do
    Reader.read_authors(content_dir)
    |> Enum.reduce(result, fn author, acc ->
      if author.avatar do
        check_ref(
          acc,
          "authors/#{author.slug}.yml",
          :avatar,
          author.avatar,
          index.media,
          "avatar media"
        )
      else
        acc
      end
    end)
  end

  # --- Reference check helpers ---

  defp check_ref(result, path, kind, value, valid_set, label \\ nil) do
    if value && !MapSet.member?(valid_set, value) do
      label = label || to_string(kind)
      available = valid_set |> MapSet.to_list() |> Enum.sort() |> Enum.join(", ")

      msg =
        if available != "" do
          "#{label} \"#{value}\" not found (available: #{available})"
        else
          "#{label} \"#{value}\" not found"
        end

      add_error(result, path, :unresolved_reference, msg)
    else
      result
    end
  end

  defp check_list_refs(result, path, kind, values, valid_set) do
    Enum.reduce(values, result, fn value, acc ->
      check_ref(acc, path, kind, value, valid_set)
    end)
  end

  # --- Schema validation ---

  defp check_schemas(result, content_dir, index, templates_by_name) do
    Reader.read_pages(content_dir)
    |> Enum.reduce(result, fn page, acc ->
      Enum.reduce(page.sections, acc, fn section, inner_acc ->
        case Map.get(templates_by_name, section.template) do
          nil -> inner_acc  # template ref error already caught
          template ->
            section_path = section_file_path(page, section, content_dir)
            validate_section_fields(inner_acc, section_path, section.fields, template, index)
        end
      end)
    end)
  end

  defp validate_section_fields(result, path, fields, template, index) do
    result
    |> check_required_fields(path, fields, template)
    |> check_field_types(path, fields, template, index)
    |> check_unknown_fields(path, fields, template)
  end

  defp check_required_fields(result, path, fields, template) do
    template.fields
    |> Enum.filter(fn {_name, def} -> def.required end)
    |> Enum.reduce(result, fn {name, _def}, acc ->
      if Map.has_key?(fields, name) do
        acc
      else
        add_error(acc, path, :missing_required_field,
          "missing required field \"#{name}\" (template: #{template.name})")
      end
    end)
  end

  defp check_field_types(result, path, fields, template, index) do
    Enum.reduce(fields, result, fn {name, value}, acc ->
      case Map.get(template.fields, name) do
        nil -> acc  # unknown field, handled by check_unknown_fields
        field_def -> validate_type(acc, path, name, value, field_def, index)
      end
    end)
  end

  defp validate_type(result, path, name, value, field_def, index) do
    case field_def.type do
      :string -> result  # anything is a valid string
      :richtext -> result  # validated structurally via .md files
      :media ->
        if is_binary(value) and MapSet.member?(index.media, value) do
          result
        else
          add_error(result, path, :unresolved_reference,
            "media \"#{value}\" not found in field \"#{name}\"")
        end
      :integer ->
        if is_integer(value) do
          result
        else
          add_error(result, path, :type_mismatch,
            "\"#{name}\" has value #{inspect(value)}, expected integer")
        end
      :boolean ->
        if is_boolean(value) do
          result
        else
          add_error(result, path, :type_mismatch,
            "\"#{name}\" has value #{inspect(value)}, expected boolean")
        end
      :url ->
        if is_binary(value) and Regex.match?(~r{^(/|https?://)}, value) do
          result
        else
          add_error(result, path, :type_mismatch,
            "\"#{name}\" has value #{inspect(value)}, expected url (must start with /, http://, or https://)")
        end
      :list ->
        if is_list(value) do
          result
        else
          add_error(result, path, :type_mismatch,
            "\"#{name}\" has value #{inspect(value)}, expected list")
        end
      :map ->
        if is_map(value) do
          result
        else
          add_error(result, path, :type_mismatch,
            "\"#{name}\" has value #{inspect(value)}, expected map")
        end
      _ -> result
    end
  end

  defp check_unknown_fields(result, path, fields, template) do
    known_fields = Map.keys(template.fields) |> MapSet.new()

    Enum.reduce(fields, result, fn {name, _value}, acc ->
      if MapSet.member?(known_fields, name) do
        acc
      else
        suggestion = fuzzy_match(name, MapSet.to_list(known_fields))

        msg = case suggestion do
          nil -> "unknown field \"#{name}\" (template: #{template.name})"
          match -> "unknown field \"#{name}\" — did you mean \"#{match}\"? (template: #{template.name})"
        end

        add_warning(acc, path, :unknown_field, msg)
      end
    end)
  end

  defp fuzzy_match(input, candidates) do
    candidates
    |> Enum.map(fn candidate -> {candidate, String.jaro_distance(input, candidate)} end)
    |> Enum.filter(fn {_c, score} -> score > 0.8 end)
    |> Enum.sort_by(fn {_c, score} -> score end, :desc)
    |> case do
      [{match, _score} | _] -> match
      [] -> nil
    end
  end

  # --- Path helpers ---

  defp page_yml_path(page, _content_dir) do
    slug_to_dir = case page.slug do
      "/" -> "index"
      slug -> String.trim_leading(slug, "/")
    end

    "pages/#{slug_to_dir}/page.yml"
  end

  defp section_file_path(page, section, _content_dir) do
    slug_to_dir = case page.slug do
      "/" -> "index"
      slug -> String.trim_leading(slug, "/")
    end

    "pages/#{slug_to_dir}/sections/#{String.pad_leading(to_string(section.position), 2, "0")}-#{section.template}"
  end

  # --- Helpers ---

  defp add_error(result, path, type, message) do
    issue = %Issue{path: path, severity: :error, type: type, message: message}
    %{result | errors: result.errors ++ [issue]}
  end

  defp add_warning(result, path, type, message) do
    issue = %Issue{path: path, severity: :warning, type: type, message: message}
    %{result | warnings: result.warnings ++ [issue]}
  end
end
