defmodule Mix.Tasks.Brix.Gen.Version do
  @moduledoc """
  Creates a new version of a Brix page.

      mix brix.gen.version SLUG [--content-dir PATH] [--copy] [--from VER]
                                [--publish]

  ## Options

    * `--copy` — copies sections from the source version
    * `--from` — source version to copy from (default: published or latest)
    * `--publish` — updates page.yml's `published_version` to the new timestamp

  ## Examples

      mix brix.gen.version home --copy --publish
      mix brix.gen.version contact --copy --from 20260101T000000Z
  """

  use Mix.Task

  @shortdoc "Create a new Brix page version"

  @impl Mix.Task
  def run(args) do
    {content_dir, opts, remaining} =
      Brix.Gen.parse_content_dir(args,
        copy: :boolean,
        from: :string,
        publish: :boolean
      )

    slug =
      case remaining do
        [slug | _] ->
          slug

        [] ->
          Mix.shell().error("Usage: mix brix.gen.version SLUG")
          exit({:shutdown, 1})
      end

    slug = Brix.Gen.normalize_slug(slug)
    page_dir = Brix.Gen.page_dir(content_dir, slug)

    unless File.dir?(page_dir) do
      Mix.shell().error("Page not found: #{slug}")
      exit({:shutdown, 1})
    end

    # Generate new timestamp
    timestamp = Brix.Reader.format_compact_iso(DateTime.utc_now())
    versions_dir = Path.join(page_dir, "versions")
    new_version_dir = Path.join(versions_dir, timestamp)

    if File.dir?(new_version_dir) do
      Mix.shell().error("Version directory already exists: #{timestamp}")
      exit({:shutdown, 1})
    end

    copy? = Keyword.get(opts, :copy, false)
    publish? = Keyword.get(opts, :publish, false)

    if copy? do
      # Resolve source version
      source_version_dir = resolve_source(page_dir, opts)
      File.mkdir_p!(new_version_dir)
      # Copy sections recursively
      source_sections = Path.join(source_version_dir, "sections")

      if File.dir?(source_sections) do
        File.cp_r!(source_sections, Path.join(new_version_dir, "sections"))
      else
        File.mkdir_p!(Path.join(new_version_dir, "sections"))
      end
    else
      File.mkdir_p!(Path.join(new_version_dir, "sections"))
    end

    # Write version.yml
    now_iso = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    version_pairs = [{"published_at", now_iso}]
    File.write!(Path.join(new_version_dir, "version.yml"), Brix.Gen.to_yaml(version_pairs))

    Mix.shell().info("Created version: #{timestamp}")
    Mix.shell().info("  #{Path.relative_to_cwd(new_version_dir)}/")

    if copy? do
      section_count =
        new_version_dir
        |> Path.join("sections")
        |> File.ls!()
        |> Enum.count(&String.ends_with?(&1, ".yml"))

      Mix.shell().info("  Copied #{section_count} section(s)")
    end

    # Update page.yml if --publish
    if publish? do
      update_published_version(page_dir, timestamp)
      Mix.shell().info("  Updated published_version → #{timestamp}")
    end
  end

  defp resolve_source(page_dir, opts) do
    case Keyword.get(opts, :from) do
      nil ->
        # Try published version first, then latest
        resolve_default_source(page_dir)

      ver ->
        existing_version_dir!(page_dir, ver, "Source version not found: #{ver}")
    end
  end

  # Falls back to the page's published version when `--from` is absent, else the latest one.
  defp resolve_default_source(page_dir) do
    page_yml = Path.join(page_dir, "page.yml")
    {:ok, data} = YamlElixir.read_from_file(page_yml)

    case data["published_version"] do
      nil ->
        latest_source!(page_dir)

      ver ->
        existing_version_dir!(page_dir, ver, "Published version not found: #{ver}")
    end
  end

  # Returns the newest version directory, aborting when the page has no versions at all.
  defp latest_source!(page_dir) do
    case Brix.Gen.latest_version(page_dir) do
      {_name, dir} ->
        dir

      nil ->
        Mix.shell().error("No versions to copy from")
        exit({:shutdown, 1})
    end
  end

  # Returns the directory for a named version, aborting with `message` when it is missing.
  defp existing_version_dir!(page_dir, ver, message) do
    dir = Path.join([page_dir, "versions", ver])

    unless File.dir?(dir) do
      Mix.shell().error(message)
      exit({:shutdown, 1})
    end

    dir
  end

  defp update_published_version(page_dir, timestamp) do
    page_yml_path = Path.join(page_dir, "page.yml")
    {:ok, data} = YamlElixir.read_from_file(page_yml_path)

    # Rebuild page.yml preserving existing fields
    pairs =
      [
        {"slug", data["slug"]},
        {"title", data["title"]}
      ]
      |> maybe_add(data, "meta_title")
      |> maybe_add(data, "meta_description")
      |> maybe_add(data, "og_title")
      |> maybe_add(data, "og_description")
      |> maybe_add(data, "og_image")
      |> maybe_add(data, "layout")
      |> Kernel.++([{"published_version", timestamp}])
      |> maybe_add(data, "authors")
      |> maybe_add(data, "tags")
      |> maybe_add(data, "slug_history")
      |> maybe_add(data, "extra")

    File.write!(page_yml_path, Brix.Gen.to_yaml(pairs))
  end

  defp maybe_add(pairs, data, key) do
    case Map.get(data, key) do
      nil -> pairs
      value -> pairs ++ [{key, value}]
    end
  end
end
