defmodule Mix.Tasks.Brix.Gen.Section do
  @moduledoc """
  Adds a section to a Brix page version.

      mix brix.gen.section SLUG TEMPLATE [--content-dir PATH] [--version VER]
                                         [--position NN] [--parent SECTION]
                                         [--field FIELD]

  ## Examples

      mix brix.gen.section home hero
      mix brix.gen.section home cta --position 10
      mix brix.gen.section home testimonial_card --parent 05-reviews-section

  ## Nested children

  Use `--parent` to create a child section inside a parent's `.children/` directory.
  The `--field` flag specifies which children field (defaults to `"children"`).
  The child template is validated against the parent's `of:` constraint.
  """

  use Mix.Task

  @shortdoc "Add a section to a Brix page"

  @impl Mix.Task
  def run(args) do
    {content_dir, opts, remaining} =
      Brix.Gen.parse_content_dir(args,
        version: :string,
        position: :integer,
        parent: :string,
        field: :string
      )

    {slug, template_name} = parse_slug_and_template!(remaining)

    slug = Brix.Gen.normalize_slug(slug)
    page_dir = Brix.Gen.page_dir(content_dir, slug)
    ensure_page_exists!(page_dir, slug)

    # Load templates and validate
    templates = Brix.Gen.templates_by_name(content_dir)
    template = fetch_template!(templates, template_name)

    # Resolve version and target directory
    {_version_name, version_dir} = Brix.Gen.resolve_version(page_dir, opts)
    sections_dir = Path.join(version_dir, "sections")
    File.mkdir_p!(sections_dir)

    target_dir = resolve_target_dir(sections_dir, opts, templates, template)

    # Determine position
    position = resolve_position(opts, target_dir)

    # Build filename
    padded = Brix.Gen.pad_position(position)
    filename = "#{padded}-#{Brix.Gen.template_to_filename(template.name)}.yml"
    file_path = Path.join(target_dir, filename)

    ensure_section_absent!(file_path)

    File.write!(file_path, Brix.Gen.to_yaml(section_pairs(template)))
    Mix.shell().info("Created section: #{Path.relative_to_cwd(file_path)}")

    create_children_dirs(target_dir, filename, template)
  end

  # Pulls SLUG and TEMPLATE out of the leftover args, aborting with usage on a bad call.
  defp parse_slug_and_template!(remaining) do
    case remaining do
      [slug, template | _] ->
        {slug, template}

      _ ->
        Mix.shell().error("Usage: mix brix.gen.section SLUG TEMPLATE")
        exit({:shutdown, 1})
    end
  end

  # Aborts unless the page directory for the given slug exists.
  defp ensure_page_exists!(page_dir, slug) do
    unless File.dir?(page_dir) do
      Mix.shell().error("Page not found: #{slug}")
      exit({:shutdown, 1})
    end
  end

  # Looks up the named section template, listing the available ones when it is unknown.
  defp fetch_template!(templates, template_name) do
    case Brix.Gen.find_template(templates, template_name) do
      {:ok, tmpl} ->
        tmpl

      :error ->
        available = templates |> Map.keys() |> Enum.sort() |> Enum.join(", ")
        Mix.shell().error("Unknown template: #{template_name}")
        Mix.shell().error("Available: #{available}")
        exit({:shutdown, 1})
    end
  end

  # Picks the directory the new section belongs in: a parent's children dir with
  # `--parent`, otherwise the version's own sections dir.
  defp resolve_target_dir(sections_dir, opts, templates, template) do
    case Keyword.get(opts, :parent) do
      nil -> sections_dir
      parent_opt -> resolve_children_dir(sections_dir, parent_opt, opts, templates, template)
    end
  end

  # Uses the explicit `--position` when given, otherwise the next free position.
  defp resolve_position(opts, target_dir) do
    case Keyword.get(opts, :position) do
      nil -> Brix.Gen.next_position(target_dir)
      n -> n
    end
  end

  # Aborts when a section file already exists at the computed path.
  defp ensure_section_absent!(file_path) do
    if File.exists?(file_path) do
      Mix.shell().error("Section already exists: #{Path.relative_to_cwd(file_path)}")
      exit({:shutdown, 1})
    end
  end

  # Builds the section YAML key/value pairs, always emitting a `fields` entry.
  defp section_pairs(template) do
    fields = Brix.Gen.scaffold_fields(template)
    pairs = [{"template", template.name}]

    if map_size(fields) == 0 do
      pairs ++ [{"fields", %{}}]
    else
      pairs ++ [{"fields", fields}]
    end
  end

  # Creates a children directory beside the new section for each of its `:sections` fields.
  defp create_children_dirs(target_dir, filename, template) do
    for field_name <- Brix.Gen.sections_fields(template) do
      base = Path.rootname(filename, ".yml")
      children_dir = Path.join(target_dir, "#{base}.#{field_name}")
      File.mkdir_p!(children_dir)
      Mix.shell().info("Created children dir: #{Path.relative_to_cwd(children_dir)}/")
    end
  end

  defp resolve_children_dir(sections_dir, parent_name, opts, templates, child_template) do
    # Find parent section file
    parent_file = find_parent_file!(sections_dir, parent_name)

    # Determine children field name
    field = Keyword.get(opts, :field, "children")

    # Validate child template against parent's `of:` constraint
    {:ok, parent_data} = YamlElixir.read_from_file(Path.join(sections_dir, parent_file))
    validate_child_template!(parent_data["template"], templates, field, child_template)

    # Build children directory path
    parent_base = Path.rootname(parent_file, ".yml")
    children_dir = Path.join(sections_dir, "#{parent_base}.#{field}")
    File.mkdir_p!(children_dir)
    children_dir
  end

  # Returns the parent section's filename, aborting with the available list when missing.
  defp find_parent_file!(sections_dir, parent_name) do
    case find_parent_file(sections_dir, parent_name) do
      nil ->
        Mix.shell().error("Parent section not found: #{parent_name}")

        available =
          sections_dir |> File.ls!() |> Enum.filter(&String.ends_with?(&1, ".yml")) |> Enum.sort()

        Mix.shell().error("Available: #{Enum.join(available, ", ")}")
        exit({:shutdown, 1})

      parent_file ->
        parent_file
    end
  end

  # Resolves the parent's template definition so its children field can be checked.
  defp validate_child_template!(parent_template_name, templates, field, child_template) do
    if parent_template_name do
      case Map.get(templates, parent_template_name) do
        %Brix.SectionTemplate{fields: fields} when is_map(fields) ->
          validate_children_field!(
            Map.get(fields, field),
            parent_template_name,
            field,
            child_template
          )

        _ ->
          :ok
      end
    end
  end

  # Checks the parent's named field is a `:sections` field that accepts this child template.
  defp validate_children_field!(
         %{type: :sections, of: allowed},
         parent_template_name,
         field,
         child
       )
       when is_list(allowed) do
    unless child.name in allowed do
      Mix.shell().error(
        "Template '#{child.name}' not allowed as child of '#{parent_template_name}' " <>
          "field '#{field}'. Allowed: #{Enum.join(allowed, ", ")}"
      )

      exit({:shutdown, 1})
    end
  end

  defp validate_children_field!(%{type: :sections}, _parent_template_name, _field, _child) do
    :ok
  end

  defp validate_children_field!(nil, parent_template_name, field, _child) do
    Mix.shell().error("Parent template '#{parent_template_name}' has no field '#{field}'")

    exit({:shutdown, 1})
  end

  defp validate_children_field!(%{type: type}, parent_template_name, field, _child) do
    Mix.shell().error(
      "Field '#{field}' in '#{parent_template_name}' is type :#{type}, not :sections"
    )

    exit({:shutdown, 1})
  end

  defp find_parent_file(sections_dir, parent_name) do
    sections_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".yml"))
    |> Enum.find(fn file ->
      base = Path.rootname(file, ".yml")
      base == parent_name || String.ends_with?(base, "-#{parent_name}")
    end)
  end
end
