defmodule Mix.Tasks.Brix.List do
  @moduledoc """
  Lists Brix content.

      mix brix.list pages    [--content-dir PATH]
      mix brix.list templates [--content-dir PATH] [--verbose]
      mix brix.list sections SLUG [--content-dir PATH] [--version VER]

  ## Subcommands

    * `pages` — shows slug, title, and published status for all pages
    * `templates` — shows template names (use `--verbose` for field details)
    * `sections SLUG` — shows sections for a page version
  """

  use Mix.Task

  @shortdoc "List Brix pages, templates, or sections"

  @impl Mix.Task
  def run(args) do
    {content_dir, opts, remaining} =
      Brix.Gen.parse_content_dir(args, verbose: :boolean, version: :string)

    case remaining do
      ["pages" | _] -> list_pages(content_dir)
      ["templates" | _] -> list_templates(content_dir, opts)
      ["sections", slug | _] -> list_sections(content_dir, slug, opts)
      ["sections"] -> Mix.shell().error("Usage: mix brix.list sections SLUG")
      _ -> Mix.shell().error("Usage: mix brix.list {pages|templates|sections SLUG}")
    end
  end

  defp list_pages(content_dir) do
    pages = Brix.Reader.read_pages(content_dir)

    if pages == [] do
      Mix.shell().info("No pages found.")
      return()
    end

    # Calculate column widths
    slug_width = pages |> Enum.map(&String.length(&1.slug)) |> Enum.max() |> max(4)
    title_width = pages |> Enum.map(&String.length(&1.title || "")) |> Enum.max() |> max(5)

    header =
      String.pad_trailing("SLUG", slug_width) <>
        "  " <>
        String.pad_trailing("TITLE", title_width) <>
        "  STATUS"

    Mix.shell().info(header)
    Mix.shell().info(String.duplicate("-", String.length(header)))

    for page <- pages do
      status = if page.published_version, do: "published", else: "draft"

      line =
        String.pad_trailing(page.slug, slug_width) <>
          "  " <>
          String.pad_trailing(page.title || "", title_width) <>
          "  #{status}"

      Mix.shell().info(line)
    end
  end

  defp list_templates(content_dir, opts) do
    templates = Brix.Reader.read_section_templates(content_dir)

    if templates == [] do
      Mix.shell().info("No templates found.")
      return()
    end

    if Keyword.get(opts, :verbose, false) do
      for tmpl <- templates do
        Mix.shell().info("\n#{tmpl.name}")

        fields = tmpl.fields || %{}

        if map_size(fields) == 0 do
          Mix.shell().info("  (no fields)")
        else
          for {name, def} <- Enum.sort(fields) do
            req = if def.required, do: " (required)", else: ""
            of = if def.of, do: " of: #{inspect(def.of)}", else: ""
            Mix.shell().info("  #{name}: #{def.type}#{req}#{of}")
          end
        end
      end
    else
      names = Enum.map(templates, & &1.name)
      # Print in columns
      max_len = names |> Enum.map(&String.length/1) |> Enum.max()
      col_width = max_len + 2
      term_width = 80
      cols = max(div(term_width, col_width), 1)

      names
      |> Enum.chunk_every(cols)
      |> Enum.each(fn row ->
        line = Enum.map_join(row, fn name -> String.pad_trailing(name, col_width) end)
        Mix.shell().info(line)
      end)
    end
  end

  defp list_sections(content_dir, slug, opts) do
    page_dir = Brix.Gen.page_dir(content_dir, slug)

    unless File.dir?(page_dir) do
      Mix.shell().error("Page not found: #{slug}")
      exit({:shutdown, 1})
    end

    {version_name, version_dir} = Brix.Gen.resolve_version(page_dir, opts)
    sections_dir = Path.join(version_dir, "sections")

    Mix.shell().info("Sections for #{slug} (version: #{version_name}):\n")

    unless File.dir?(sections_dir) do
      Mix.shell().info("  (no sections directory)")
      return()
    end

    entries =
      sections_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".yml"))
      |> Enum.sort()

    if entries == [] do
      Mix.shell().info("  (no sections)")
      return()
    end

    for entry <- entries do
      {:ok, data} = YamlElixir.read_from_file(Path.join(sections_dir, entry))
      template = data["template"] || "unknown"
      fields = data["fields"] || %{}
      field_names = fields |> Map.keys() |> Enum.sort() |> Enum.join(", ")

      # Check for children directory
      base = Path.rootname(entry)
      children_dir = Path.join(sections_dir, "#{base}.children")
      children_info = if File.dir?(children_dir) do
        count = children_dir |> File.ls!() |> Enum.count(&String.ends_with?(&1, ".yml"))
        " (#{count} children)"
      else
        ""
      end

      Mix.shell().info("  #{entry}")
      Mix.shell().info("    template: #{template}#{children_info}")

      if field_names != "" do
        Mix.shell().info("    fields: #{field_names}")
      end
    end
  end

  defp return, do: :ok
end
