defmodule Mix.Tasks.Brix.Gen.Page do
  @moduledoc """
  Creates a new Brix page with an initial version.

      mix brix.gen.page SLUG [--title TITLE] [--content-dir PATH]
                              [--no-publish] [--layout NAME]

  ## Examples

      mix brix.gen.page contact
      mix brix.gen.page projects/my-app --title "My App"
      mix brix.gen.page landing --no-publish --layout marketing
  """

  use Mix.Task

  @shortdoc "Create a new Brix page"

  @impl Mix.Task
  def run(args) do
    {content_dir, opts, remaining} =
      Brix.Gen.parse_content_dir(args,
        title: :string,
        no_publish: :boolean,
        layout: :string
      )

    slug =
      case remaining do
        [slug | _] -> slug
        [] ->
          Mix.shell().error("Usage: mix brix.gen.page SLUG")
          exit({:shutdown, 1})
      end

    slug = Brix.Gen.normalize_slug(slug)
    page_dir = Brix.Gen.page_dir(content_dir, slug)
    page_yml = Path.join(page_dir, "page.yml")

    if File.exists?(page_yml) do
      Mix.shell().error("Page already exists: #{page_yml}")
      exit({:shutdown, 1})
    end

    # Derive title from last slug segment
    last_segment = slug |> String.split("/") |> List.last()
    title = Keyword.get(opts, :title, Brix.Gen.titleize(last_segment))
    no_publish = Keyword.get(opts, :no_publish, false)
    layout = Keyword.get(opts, :layout)

    # Generate version timestamp
    timestamp = Brix.Reader.format_compact_iso(DateTime.utc_now())

    # Build page.yml content
    page_pairs = [{"slug", slug}, {"title", title}]
    page_pairs = if layout, do: page_pairs ++ [{"layout", layout}], else: page_pairs
    page_pairs = if no_publish, do: page_pairs, else: page_pairs ++ [{"published_version", timestamp}]

    # Build version.yml content
    now_iso = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    version_pairs = [{"published_at", now_iso}]

    # Create directory structure
    version_dir = Path.join([page_dir, "versions", timestamp])
    sections_dir = Path.join(version_dir, "sections")

    File.mkdir_p!(sections_dir)
    File.write!(page_yml, Brix.Gen.to_yaml(page_pairs))
    File.write!(Path.join(version_dir, "version.yml"), Brix.Gen.to_yaml(version_pairs))

    Mix.shell().info("Created page: #{slug}")
    Mix.shell().info("  #{Path.relative_to_cwd(page_yml)}")
    Mix.shell().info("  #{Path.relative_to_cwd(version_dir)}/")
    Mix.shell().info("")
    Mix.shell().info("Next: mix brix.gen.section #{String.trim_leading(slug, "/")} hero")
  end
end
