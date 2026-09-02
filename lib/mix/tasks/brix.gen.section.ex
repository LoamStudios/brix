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

    {slug, template_name} =
      case remaining do
        [slug, template | _] ->
          {slug, template}

        _ ->
          Mix.shell().error("Usage: mix brix.gen.section SLUG TEMPLATE")
          exit({:shutdown, 1})
      end

    slug = Brix.Gen.normalize_slug(slug)
    page_dir = Brix.Gen.page_dir(content_dir, slug)

    unless File.dir?(page_dir) do
      Mix.shell().error("Page not found: #{slug}")
      exit({:shutdown, 1})
    end

    # Load templates and validate
    templates = Brix.Gen.templates_by_name(content_dir)

    template =
      case Brix.Gen.find_template(templates, template_name) do
        {:ok, tmpl} ->
          tmpl

        :error ->
          available = templates |> Map.keys() |> Enum.sort() |> Enum.join(", ")
          Mix.shell().error("Unknown template: #{template_name}")
          Mix.shell().error("Available: #{available}")
          exit({:shutdown, 1})
      end

    # Resolve version and target directory
    {_version_name, version_dir} = Brix.Gen.resolve_version(page_dir, opts)
    sections_dir = Path.join(version_dir, "sections")
    File.mkdir_p!(sections_dir)

    parent_opt = Keyword.get(opts, :parent)

    target_dir =
      if parent_opt do
        resolve_children_dir(sections_dir, parent_opt, opts, templates, template)
      else
        sections_dir
      end

    # Determine position
    position =
      case Keyword.get(opts, :position) do
        nil -> Brix.Gen.next_position(target_dir)
        n -> n
      end

    # Build filename
    padded = Brix.Gen.pad_position(position)
    filename = "#{padded}-#{Brix.Gen.template_to_filename(template.name)}.yml"
    file_path = Path.join(target_dir, filename)

    if File.exists?(file_path) do
      Mix.shell().error("Section already exists: #{Path.relative_to_cwd(file_path)}")
      exit({:shutdown, 1})
    end

    # Scaffold fields
    fields = Brix.Gen.scaffold_fields(template)

    # Build section YAML
    pairs = [{"template", template.name}]

    pairs =
      if map_size(fields) == 0 do
        pairs ++ [{"fields", %{}}]
      else
        pairs ++ [{"fields", fields}]
      end

    File.write!(file_path, Brix.Gen.to_yaml(pairs))
    Mix.shell().info("Created section: #{Path.relative_to_cwd(file_path)}")

    # Create .children/ directories for :sections fields
    sections_field_names = Brix.Gen.sections_fields(template)

    for field_name <- sections_field_names do
      base = Path.rootname(filename, ".yml")
      children_dir = Path.join(target_dir, "#{base}.#{field_name}")
      File.mkdir_p!(children_dir)
      Mix.shell().info("Created children dir: #{Path.relative_to_cwd(children_dir)}/")
    end
  end

  defp resolve_children_dir(sections_dir, parent_name, opts, templates, child_template) do
    # Find parent section file
    parent_file = find_parent_file(sections_dir, parent_name)

    unless parent_file do
      Mix.shell().error("Parent section not found: #{parent_name}")

      available =
        sections_dir |> File.ls!() |> Enum.filter(&String.ends_with?(&1, ".yml")) |> Enum.sort()

      Mix.shell().error("Available: #{Enum.join(available, ", ")}")
      exit({:shutdown, 1})
    end

    # Determine children field name
    field = Keyword.get(opts, :field, "children")

    # Validate child template against parent's `of:` constraint
    {:ok, parent_data} = YamlElixir.read_from_file(Path.join(sections_dir, parent_file))
    parent_template_name = parent_data["template"]

    if parent_template_name do
      case Map.get(templates, parent_template_name) do
        %Brix.SectionTemplate{fields: fields} when is_map(fields) ->
          case Map.get(fields, field) do
            %{type: :sections, of: allowed} when is_list(allowed) ->
              unless child_template.name in allowed do
                Mix.shell().error(
                  "Template '#{child_template.name}' not allowed as child of '#{parent_template_name}' " <>
                    "field '#{field}'. Allowed: #{Enum.join(allowed, ", ")}"
                )

                exit({:shutdown, 1})
              end

            %{type: :sections} ->
              :ok

            nil ->
              Mix.shell().error(
                "Parent template '#{parent_template_name}' has no field '#{field}'"
              )

              exit({:shutdown, 1})

            %{type: type} ->
              Mix.shell().error(
                "Field '#{field}' in '#{parent_template_name}' is type :#{type}, not :sections"
              )

              exit({:shutdown, 1})
          end

        _ ->
          :ok
      end
    end

    # Build children directory path
    parent_base = Path.rootname(parent_file, ".yml")
    children_dir = Path.join(sections_dir, "#{parent_base}.#{field}")
    File.mkdir_p!(children_dir)
    children_dir
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
