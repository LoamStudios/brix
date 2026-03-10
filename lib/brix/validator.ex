defmodule Brix.Validator do
  @moduledoc """
  Validates a content directory against structural rules, referential integrity,
  and section template schemas. Returns errors (block loading) and warnings (don't block).
  """

  alias Brix.Validator.Issue
  alias Brix.Reader
  alias Brix.Collection.Condition

  @type result :: %{errors: [Issue.t()], warnings: [Issue.t()]}

  @doc """
  Validates the content tree at `content_dir`. Returns `%{errors: [], warnings: []}`.
  An empty `errors` list means the content is safe to load.
  """
  @spec validate(String.t()) :: result()
  def validate(content_dir) do
    # Build an index of all known slugs for reference checking
    index = build_index(content_dir)

    # Read content once, pass through all checks
    pages = Reader.read_pages(content_dir)
    layouts = Reader.read_layouts(content_dir)
    templates = Reader.read_section_templates(content_dir)
    templates_by_name = Map.new(templates, &{&1.name, &1})

    collections = Reader.read_collections(content_dir)

    %{errors: [], warnings: []}
    |> check_structure(content_dir)
    |> check_references(content_dir, pages, layouts, index)
    |> check_schemas(pages, index, templates_by_name)
    |> check_collections(collections, index)
  end

  # --- Index ---

  defp build_index(content_dir) do
    %{
      layouts: read_slugs(content_dir, "layouts/*.yml"),
      authors: read_slugs(content_dir, "authors/*.yml"),
      tags: read_slugs(content_dir, "tags/*.yml"),
      media: read_slugs(content_dir, "media/*.yml"),
      section_templates: read_slugs(content_dir, "templates/sections/*.yml"),
      shared_sections: read_slugs(content_dir, "shared_sections/*.yml")
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
      # Find dirs that have page.yml OR versions/ (to catch orphans missing page.yml)
      page_dirs = find_page_candidate_dirs(pages_dir)

      Enum.reduce(page_dirs, result, fn page_dir, acc ->
        page_yml = Path.join(page_dir, "page.yml")

        if File.exists?(page_yml) do
          check_version_dirs(acc, page_dir, content_dir)
        else
          relative = Path.relative_to(page_dir, content_dir)
          add_error(acc, relative, :missing_file, "page.yml not found in #{relative}")
        end
      end)
    else
      result
    end
  end

  defp find_page_candidate_dirs(pages_dir) do
    # Directories that contain page.yml
    from_page_yml =
      pages_dir
      |> Path.join("**/page.yml")
      |> Path.wildcard()
      |> Enum.map(&Path.dirname/1)

    # Directories that contain versions/ (catches orphans missing page.yml)
    from_versions =
      pages_dir
      |> Path.join("**/versions")
      |> Path.wildcard()
      |> Enum.filter(&File.dir?/1)
      |> Enum.map(&Path.dirname/1)

    (from_page_yml ++ from_versions)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp check_version_dirs(result, page_dir, content_dir) do
    versions_dir = Path.join(page_dir, "versions")

    if File.dir?(versions_dir) do
      version_dirs =
        versions_dir
        |> File.ls!()
        |> Enum.filter(fn name ->
          File.dir?(Path.join(versions_dir, name)) && Reader.parse_compact_iso(name) != nil
        end)

      Enum.reduce(version_dirs, result, fn name, acc ->
        version_path = Path.join(versions_dir, name)
        version_yml = Path.join(version_path, "version.yml")
        relative = Path.relative_to(version_path, content_dir)

        if File.exists?(version_yml) do
          acc
        else
          add_error(acc, relative, :missing_file, "version.yml not found in #{relative}")
        end
      end)
    else
      result
    end
  end

  # --- Referential integrity ---

  defp check_references(result, content_dir, pages, layouts, index) do
    result
    |> check_page_references(pages, content_dir, index)
    |> check_section_references(pages, content_dir, index)
    |> check_layout_references(layouts, index)
    |> check_media_files(content_dir)
    |> check_author_avatars(content_dir, index)
  end

  defp check_page_references(result, pages, content_dir, index) do
    Enum.reduce(pages, result, fn page, acc ->
      page_path = page_yml_path(page, content_dir)

      acc
      |> check_ref(page_path, :layout, page.layout, index.layouts)
      |> check_list_refs(page_path, :author, page.authors, index.authors)
      |> check_list_refs(page_path, :tag, page.tags, index.tags)
      |> check_published_version(page_path, page)
    end)
  end

  defp check_published_version(result, page_path, page) do
    if page.published_version do
      version_ids = Enum.map(page.versions || [], & &1.version)

      if page.published_version in version_ids do
        result
      else
        add_error(result, page_path, :unresolved_reference,
          "published_version references nonexistent version")
      end
    else
      result
    end
  end

  defp check_section_references(result, pages, _content_dir, index) do
    Enum.reduce(pages, result, fn page, acc ->
      Enum.reduce(page.versions || [], acc, fn version, ver_acc ->
        Enum.reduce(version.sections, ver_acc, fn section, inner_acc ->
          section_path = version_section_file_path(page, version, section)
          check_section_or_shared_ref(inner_acc, section_path, section, index)
        end)
      end)
    end)
  end

  defp check_layout_references(result, layouts, index) do
    Enum.reduce(layouts, result, fn layout, acc ->
      layout_path = "layouts/#{layout.name}.yml"
      all_sections = layout.header_sections ++ layout.footer_sections

      Enum.reduce(all_sections, acc, fn section, inner_acc ->
        check_section_or_shared_ref(inner_acc, layout_path, section, index)
      end)
    end)
  end

  defp check_section_or_shared_ref(result, path, section, index) do
    case section.fields do
      %{"__shared_section_ref" => ref_name} ->
        check_ref(result, path, :shared_section, ref_name, index.shared_sections)

      _ ->
        check_ref(result, path, :template, section.template, index.section_templates)
    end
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

  defp check_schemas(result, pages, index, templates_by_name) do
    Enum.reduce(pages, result, fn page, acc ->
      Enum.reduce(page.versions || [], acc, fn version, ver_acc ->
        Enum.reduce(version.sections, ver_acc, fn section, inner_acc ->
          case Map.get(templates_by_name, section.template) do
            nil -> inner_acc  # template ref error already caught
            template ->
              section_path = version_section_file_path(page, version, section)
              validate_section_recursive(inner_acc, section_path, section, template, index, templates_by_name)
          end
        end)
      end)
    end)
  end

  defp validate_section_recursive(result, path, section, template, index, templates_by_name) do
    result
    |> validate_section_fields(path, section.fields, template, index)
    |> check_required_sections_fields(path, section, template)
    |> validate_children(path, section, template, index, templates_by_name)
    |> check_unexpected_children(path, section, template)
  end

  defp validate_section_fields(result, path, fields, template, index) do
    result
    |> check_required_fields(path, fields, template)
    |> check_field_types(path, fields, template, index)
    |> check_unknown_fields(path, fields, template)
  end

  defp check_required_fields(result, path, fields, template) do
    template.fields
    |> Enum.filter(fn {_name, def} -> def.required and def.type != :sections end)
    |> Enum.reduce(result, fn {name, _def}, acc ->
      if Map.has_key?(fields, name) do
        acc
      else
        add_error(acc, path, :missing_required_field,
          "missing required field \"#{name}\" (template: #{template.name})")
      end
    end)
  end

  defp check_required_sections_fields(result, path, section, template) do
    template.fields
    |> Enum.filter(fn {_name, def} -> def.required and def.type == :sections end)
    |> Enum.reduce(result, fn {name, _def}, acc ->
      children = Map.get(section.children, name, [])

      if children != [] do
        acc
      else
        add_error(acc, path, :missing_required_field,
          "missing required field \"#{name}\" (template: #{template.name})")
      end
    end)
  end

  defp validate_children(result, path, section, template, index, templates_by_name) do
    children = section.children || %{}

    Enum.reduce(children, result, fn {field_name, child_sections}, acc ->
      field_def = Map.get(template.fields, field_name)

      Enum.reduce(child_sections, acc, fn child, inner_acc ->
        child_path = "#{path}.#{field_name}/#{String.pad_leading(to_string(child.position), 2, "0")}-#{child.template}"

        # Check of constraint
        inner_acc =
          if field_def && field_def.type == :sections && field_def.of do
            if child.template in field_def.of do
              inner_acc
            else
              allowed = Enum.join(field_def.of, ", ")
              add_error(inner_acc, child_path, :invalid_child_template,
                "template \"#{child.template}\" not allowed here (allowed: #{allowed})")
            end
          else
            inner_acc
          end

        # Recursively validate child
        case Map.get(templates_by_name, child.template) do
          nil -> inner_acc
          child_template ->
            validate_section_recursive(inner_acc, child_path, child, child_template, index, templates_by_name)
        end
      end)
    end)
  end

  defp check_unexpected_children(result, path, section, template) do
    sections_fields =
      template.fields
      |> Enum.filter(fn {_name, def} -> def.type == :sections end)
      |> Enum.map(fn {name, _def} -> name end)
      |> MapSet.new()

    children = section.children || %{}

    Enum.reduce(children, result, fn {field_name, _child_sections}, acc ->
      if MapSet.member?(sections_fields, field_name) do
        acc
      else
        add_warning(acc, path, :unexpected_children,
          "children directory \"#{field_name}\" has no matching sections field (template: #{template.name})")
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
        if is_binary(value) and Regex.match?(~r{^(/|https?://|#)}, value) do
          result
        else
          add_error(result, path, :type_mismatch,
            "\"#{name}\" has value #{inspect(value)}, expected url (must start with /, #, http://, or https://)")
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

  # --- Collection validation ---

  defp check_collections(result, collections, index) do
    collection_slugs = MapSet.new(collections, & &1.slug)

    Enum.reduce(collections, result, fn collection, acc ->
      path = "collections/#{collection.slug}.yml"

      acc
      |> check_collection_parent(path, collection, collection_slugs)
      |> check_collection_circular_parent(path, collection, collections)
      |> check_collection_filter_groups(path, collection)
      |> check_collection_condition_refs(path, collection, index)
    end)
  end

  defp check_collection_parent(result, _path, %{parent: nil}, _collection_slugs), do: result

  defp check_collection_parent(result, path, collection, collection_slugs) do
    if MapSet.member?(collection_slugs, collection.parent) do
      result
    else
      add_error(result, path, :unresolved_reference,
        "parent \"#{collection.parent}\" not found")
    end
  end

  defp check_collection_circular_parent(result, _path, %{parent: nil}, _collections), do: result

  defp check_collection_circular_parent(result, path, collection, collections) do
    by_slug = Map.new(collections, &{&1.slug, &1})

    if circular_parent?(collection.slug, collection.parent, by_slug, MapSet.new()) do
      add_error(result, path, :circular_reference,
        "circular parent reference detected (#{collection.slug} -> #{collection.parent})")
    else
      result
    end
  end

  defp circular_parent?(_origin, nil, _by_slug, _visited), do: false

  defp circular_parent?(origin, current_slug, by_slug, visited) do
    cond do
      current_slug == origin -> true
      MapSet.member?(visited, current_slug) -> false
      true ->
        case Map.get(by_slug, current_slug) do
          nil -> false
          collection -> circular_parent?(origin, collection.parent, by_slug, MapSet.put(visited, current_slug))
        end
    end
  end

  defp check_collection_filter_groups(result, _path, %{filter_groups: nil}), do: result
  defp check_collection_filter_groups(result, _path, %{filter_groups: []}), do: result

  defp check_collection_filter_groups(result, path, collection) do
    Enum.reduce(collection.filter_groups, result, fn group, acc ->
      unless group.logic in [:and, :or] do
        add_error(acc, path, :invalid_filter_group,
          "filter group logic must be \"and\" or \"or\", got: #{inspect(group.logic)}")
      else
        Enum.reduce(group.conditions, acc, fn condition, inner_acc ->
          if condition.type in Condition.valid_types() do
            inner_acc
          else
            add_error(inner_acc, path, :invalid_condition_type,
              "unknown condition type \"#{condition.type}\" (valid: #{Condition.valid_types() |> Enum.join(", ")})")
          end
        end)
      end
    end)
  end

  defp check_collection_condition_refs(result, path, collection, index) do
    groups = collection.filter_groups || []

    Enum.reduce(groups, result, fn group, acc ->
      Enum.reduce(group.conditions, acc, fn condition, inner_acc ->
        case condition.type do
          :tag ->
            Enum.reduce(condition.value, inner_acc, fn v, a ->
              check_ref(a, path, :tag, v, index.tags)
            end)

          :author ->
            Enum.reduce(condition.value, inner_acc, fn v, a ->
              check_ref(a, path, :author, v, index.authors)
            end)

          _ ->
            inner_acc
        end
      end)
    end)
  end

  # --- Path helpers ---

  defp page_yml_path(page, _content_dir) do
    slug_to_dir = case page.slug do
      "/" -> "index"
      slug -> String.trim_leading(slug, "/")
    end

    "pages/#{slug_to_dir}/page.yml"
  end

  defp version_section_file_path(page, version, section) do
    slug_to_dir = case page.slug do
      "/" -> "index"
      slug -> String.trim_leading(slug, "/")
    end

    version_name = Reader.format_compact_iso(version.version)

    "pages/#{slug_to_dir}/versions/#{version_name}/sections/#{String.pad_leading(to_string(section.position), 2, "0")}-#{section.template}"
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
