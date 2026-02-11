defmodule Brix.Gen do
  @moduledoc """
  Shared helpers for Brix generator mix tasks.
  """

  @doc """
  Parses `--content-dir` from args, defaulting to `priv/content`.
  Returns `{content_dir, parsed_opts, remaining_args}`.

  `extra_switches` are merged with the base `[content_dir: :string]`.
  """
  def parse_content_dir(args, extra_switches \\ []) do
    switches = Keyword.merge([content_dir: :string], extra_switches)

    {opts, remaining, _invalid} =
      OptionParser.parse(args, strict: switches)

    content_dir =
      opts
      |> Keyword.get(:content_dir, "priv/content")
      |> Path.expand()

    unless File.dir?(content_dir) do
      Mix.shell().error("Content directory not found: #{content_dir}")
      exit({:shutdown, 1})
    end

    {content_dir, opts, remaining}
  end

  @doc """
  Returns a map of template name → %SectionTemplate{}.
  """
  def templates_by_name(content_dir) do
    content_dir
    |> Brix.Reader.read_section_templates()
    |> Map.new(&{&1.name, &1})
  end

  @doc """
  Finds a template by name. Normalizes hyphens to underscores.
  Returns `{:ok, template}` or `:error`.
  """
  def find_template(templates_map, name) do
    normalized = String.replace(name, "-", "_")

    case Map.fetch(templates_map, normalized) do
      {:ok, _} = result -> result
      :error -> :error
    end
  end

  @doc """
  Generates YAML from an ordered list of `{key, value}` pairs.
  Handles strings, numbers, booleans, nil, empty maps, and
  one level of nested maps (for `fields:` blocks).
  """
  def to_yaml(pairs) do
    pairs
    |> Enum.map(&yaml_pair/1)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp yaml_pair({key, value}) when is_map(value) and map_size(value) == 0 do
    "#{key}: {}"
  end

  defp yaml_pair({key, value}) when is_map(value) do
    nested =
      value
      |> Enum.map(fn {k, v} -> "  #{k}: #{yaml_scalar(v)}" end)
      |> Enum.join("\n")

    "#{key}:\n#{nested}"
  end

  defp yaml_pair({key, value}) do
    "#{key}: #{yaml_scalar(value)}"
  end

  defp yaml_scalar(nil), do: ""
  defp yaml_scalar(true), do: "true"
  defp yaml_scalar(false), do: "false"
  defp yaml_scalar(value) when is_integer(value), do: Integer.to_string(value)

  defp yaml_scalar(value) when is_binary(value) do
    if needs_quoting?(value), do: ~s("#{escape_yaml(value)}"), else: value
  end

  defp yaml_scalar(value), do: inspect(value)

  defp needs_quoting?(""), do: false
  defp needs_quoting?("true"), do: true
  defp needs_quoting?("false"), do: true
  defp needs_quoting?("null"), do: true
  defp needs_quoting?("yes"), do: true
  defp needs_quoting?("no"), do: true

  defp needs_quoting?(value) do
    String.contains?(value, [": ", "#", "\"", "\n", "'", "{", "}", "[", "]"]) or
      String.starts_with?(value, [" ", "-", "?", ">", "|", "*", "&", "!"])
  end

  defp escape_yaml(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  @doc """
  Converts a template name to a kebab-case filename segment.
  `"reviews_section"` → `"reviews-section"`
  """
  def template_to_filename(name) do
    String.replace(name, "_", "-")
  end

  @doc """
  Scans a directory for `{NN}-*` files/dirs and returns the next position number.
  Returns 1 if the directory is empty or doesn't exist.
  """
  def next_position(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.map(&extract_position/1)
      |> Enum.filter(& &1)
      |> case do
        [] -> 1
        positions -> Enum.max(positions) + 1
      end
    else
      1
    end
  end

  defp extract_position(name) do
    case Regex.run(~r/^(\d+)-/, name) do
      [_, n] -> String.to_integer(n)
      nil -> nil
    end
  end

  @doc """
  Zero-pads a number to 2 digits.
  """
  def pad_position(n) when is_integer(n) do
    n |> Integer.to_string() |> String.pad_leading(2, "0")
  end

  @doc """
  Generates placeholder field values from a template definition.
  Required strings get `"TODO"`, optional get `""`, booleans get `false`, etc.
  Skips `:sections` type fields (those become `.children/` directories).
  """
  def scaffold_fields(%Brix.SectionTemplate{fields: nil}), do: %{}

  def scaffold_fields(%Brix.SectionTemplate{fields: fields}) do
    fields
    |> Enum.reject(fn {_name, def} ->
      def.type == :sections or skip_optional?(def)
    end)
    |> Map.new(fn {name, def} -> {name, placeholder_value(def)} end)
  end

  # Skip optional fields whose placeholder would fail validation
  defp skip_optional?(%{required: true}), do: false
  defp skip_optional?(%{type: type}) when type in [:url, :media], do: true
  defp skip_optional?(_), do: false

  defp placeholder_value(%{type: :string, required: true}), do: "TODO"
  defp placeholder_value(%{type: :string}), do: ""
  defp placeholder_value(%{type: :richtext, required: true}), do: "TODO"
  defp placeholder_value(%{type: :richtext}), do: ""
  defp placeholder_value(%{type: :url}), do: "/"
  defp placeholder_value(%{type: :integer}), do: 0
  defp placeholder_value(%{type: :boolean}), do: false
  defp placeholder_value(%{type: :media}), do: "TODO"
  defp placeholder_value(%{type: :list}), do: []
  defp placeholder_value(%{type: :map}), do: %{}
  defp placeholder_value(_), do: ""

  @doc """
  Returns the field names in a template that have type `:sections`.
  """
  def sections_fields(%Brix.SectionTemplate{fields: nil}), do: []

  def sections_fields(%Brix.SectionTemplate{fields: fields}) do
    fields
    |> Enum.filter(fn {_name, def} -> def.type == :sections end)
    |> Enum.map(fn {name, _def} -> name end)
  end

  @doc """
  Runs `Brix.Validator.validate/1`, prints issues, returns `:ok` or `:error`.
  """
  def validate_and_report(content_dir) do
    result = Brix.Validator.validate(content_dir)

    for issue <- result.errors do
      Mix.shell().error("error: #{issue.path}: #{issue.message}")
    end

    for issue <- result.warnings do
      Mix.shell().info("warning: #{issue.path}: #{issue.message}")
    end

    if length(result.errors) > 0, do: :error, else: :ok
  end

  @doc """
  Resolves the page directory for a given slug.
  Slug `/` maps to `index/`, others strip leading `/`.
  """
  def page_dir(content_dir, slug) do
    dir_name =
      case normalize_slug(slug) do
        "/" -> "index"
        s -> String.trim_leading(s, "/")
      end

    Path.join([content_dir, "pages", dir_name])
  end

  @doc """
  Normalizes a slug: strips leading `/`, lowercases, validates characters,
  then prepends `/`.
  """
  def normalize_slug(slug) do
    slug = slug |> String.trim_leading("/") |> String.downcase()

    unless Regex.match?(~r/^[a-z0-9\-\/]*$/, slug) do
      Mix.shell().error("Invalid slug: #{slug} (only a-z, 0-9, hyphens, and slashes)")
      exit({:shutdown, 1})
    end

    "/" <> slug
  end

  @doc """
  Titleizes a slug segment: `"my-page"` → `"My Page"`.
  """
  def titleize(slug) do
    slug
    |> String.split("-")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Finds the latest version directory in a page dir, by timestamp.
  Returns `{version_name, version_dir}` or `nil`.
  """
  def latest_version(page_dir) do
    versions_dir = Path.join(page_dir, "versions")

    if File.dir?(versions_dir) do
      versions_dir
      |> File.ls!()
      |> Enum.filter(fn name ->
        File.dir?(Path.join(versions_dir, name)) &&
          Brix.Reader.parse_compact_iso(name) != nil
      end)
      |> Enum.sort_by(&Brix.Reader.parse_compact_iso/1, {:desc, DateTime})
      |> case do
        [latest | _] -> {latest, Path.join(versions_dir, latest)}
        [] -> nil
      end
    else
      nil
    end
  end

  @doc """
  Resolves which version to use: explicit `--version` option, or latest.
  Returns `{version_name, version_dir}` or exits with error.
  """
  def resolve_version(page_dir, opts) do
    case Keyword.get(opts, :version) do
      nil ->
        case latest_version(page_dir) do
          nil ->
            Mix.shell().error("No versions found in #{page_dir}")
            exit({:shutdown, 1})

          result ->
            result
        end

      ver ->
        versions_dir = Path.join(page_dir, "versions")
        version_dir = Path.join(versions_dir, ver)

        unless File.dir?(version_dir) do
          Mix.shell().error("Version not found: #{ver}")
          exit({:shutdown, 1})
        end

        {ver, version_dir}
    end
  end
end
