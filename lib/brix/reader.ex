defmodule Brix.Reader do
  @moduledoc """
  Reads content files from the filesystem into Brix structs.

  All functions take a `content_dir` path as the root of the content tree.
  """

  alias Brix.{Site, Author, Tag, Media, SectionTemplate, Section, SharedSection, Layout, Page, Collection}

  # --- Site ---

  def read_site(content_dir) do
    path = Path.join(content_dir, "site.yml")

    case read_yaml(path) do
      {:ok, data} ->
        {:ok,
         %Site{
           name: data["name"],
           tagline: data["tagline"],
           meta_title: data["meta_title"],
           meta_description: data["meta_description"],
           og_image: data["og_image"],
           favicon: data["favicon"],
           domain: data["domain"],
           extra: data["extra"]
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- Authors ---

  def read_authors(content_dir) do
    content_dir
    |> Path.join("authors/*.yml")
    |> Path.wildcard()
    |> Enum.map(&read_author/1)
    |> Enum.sort_by(& &1.slug)
  end

  defp read_author(path) do
    {:ok, data} = read_yaml(path)
    slug = path |> Path.basename(".yml")

    %Author{
      slug: slug,
      name: data["name"],
      bio: data["bio"],
      avatar: data["avatar"],
      url: data["url"],
      extra: data["extra"]
    }
  end

  # --- Tags ---

  def read_tags(content_dir) do
    content_dir
    |> Path.join("tags/*.yml")
    |> Path.wildcard()
    |> Enum.map(&read_tag/1)
    |> Enum.sort_by(& &1.slug)
  end

  defp read_tag(path) do
    {:ok, data} = read_yaml(path)
    slug = path |> Path.basename(".yml")

    %Tag{
      slug: slug,
      display_name: data["display_name"]
    }
  end

  # --- Media ---

  def read_media(content_dir) do
    content_dir
    |> Path.join("media/*.yml")
    |> Path.wildcard()
    |> Enum.map(&read_media_asset/1)
    |> Enum.sort_by(& &1.slug)
  end

  defp read_media_asset(path) do
    {:ok, data} = read_yaml(path)
    slug = path |> Path.basename(".yml")

    %Media{
      slug: slug,
      path: data["path"],
      alt: data["alt"],
      caption: data["caption"],
      content_type: data["content_type"],
      extra: data["extra"]
    }
  end

  # --- Shared Sections ---

  def read_shared_sections(content_dir) do
    content_dir
    |> Path.join("shared_sections/*.yml")
    |> Path.wildcard()
    |> Enum.map(&read_shared_section/1)
    |> Enum.sort_by(& &1.name)
  end

  defp read_shared_section(path) do
    {:ok, data} = read_yaml(path)
    name = path |> Path.basename(".yml")

    %SharedSection{
      name: name,
      template: data["template"],
      fields: data["fields"] || %{}
    }
  end

  # --- Collections ---

  def read_collections(content_dir) do
    content_dir
    |> Path.join("collections/*.yml")
    |> Path.wildcard()
    |> Enum.map(&read_collection/1)
    |> Enum.sort_by(& &1.slug)
  end

  defp read_collection(path) do
    {:ok, data} = read_yaml(path)
    slug = path |> Path.basename(".yml")
    filters = parse_filters(data["filters"] || %{})
    direction = parse_sort_direction(data["sort_direction"])

    %Collection{
      slug: slug,
      name: data["name"],
      filters: filters,
      sort_by: data["sort_by"],
      sort_direction: direction,
      meta_title: data["meta_title"],
      meta_description: data["meta_description"],
      og_title: data["og_title"],
      og_description: data["og_description"],
      og_image: data["og_image"],
      extra: data["extra"]
    }
  end

  defp parse_filters(raw) do
    Enum.into(raw, %{}, fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp parse_sort_direction("desc"), do: :desc
  defp parse_sort_direction(_), do: :asc

  # --- Section Templates ---

  def read_section_templates(content_dir) do
    content_dir
    |> Path.join("templates/sections/*.yml")
    |> Path.wildcard()
    |> Enum.map(&read_section_template/1)
    |> Enum.sort_by(& &1.name)
  end

  defp read_section_template(path) do
    {:ok, data} = read_yaml(path)
    name = path |> Path.basename(".yml")

    fields =
      (data["fields"] || %{})
      |> Enum.into(%{}, fn {field_name, field_def} ->
        {field_name,
         %{
           type: String.to_atom(field_def["type"] || "string"),
           required: field_def["required"] == true,
           of: if(field_def["of"], do: String.to_atom(field_def["of"]))
         }}
      end)

    %SectionTemplate{name: name, fields: fields}
  end

  # --- Sections ---

  def read_sections(sections_dir) do
    if File.dir?(sections_dir) do
      yml_files = Path.wildcard(Path.join(sections_dir, "*.yml"))
      md_files = Path.wildcard(Path.join(sections_dir, "*.md"))

      yml_sections = Enum.map(yml_files, &read_yml_section/1)
      md_sections = Enum.map(md_files, &read_md_section/1)

      (yml_sections ++ md_sections)
      |> Enum.sort_by(& &1.position)
    else
      []
    end
  end

  defp read_yml_section(path) do
    {:ok, data} = read_yaml(path)
    {position, template} = parse_section_filename(path)

    if data["shared_section"] do
      # Mark as a reference to be resolved later
      %Section{
        template: :shared_ref,
        position: position,
        fields: %{"__shared_section_ref" => data["shared_section"]}
      }
    else
      %Section{
        template: data["template"] || template,
        position: position,
        fields: data["fields"] || %{}
      }
    end
  end

  defp read_md_section(path) do
    {frontmatter, body} = read_markdown(path)
    {position, template} = parse_section_filename(path)

    %Section{
      template: frontmatter["template"] || template,
      position: position,
      fields: Map.put(frontmatter["fields"] || %{}, "body", markdown_to_html(body))
    }
  end

  defp parse_section_filename(path) do
    basename = Path.basename(path) |> Path.rootname()

    case Regex.run(~r/^(\d+)-(.+)$/, basename) do
      [_, position, name] -> {String.to_integer(position), name}
      nil -> {0, basename}
    end
  end

  # --- Layouts ---

  def read_layouts(content_dir) do
    content_dir
    |> Path.join("layouts/*.yml")
    |> Path.wildcard()
    |> Enum.map(&read_layout/1)
    |> Enum.sort_by(& &1.name)
  end

  defp read_layout(path) do
    {:ok, data} = read_yaml(path)
    name = path |> Path.basename(".yml")

    %Layout{
      name: name,
      header_sections: parse_inline_sections(data["header_sections"] || []),
      footer_sections: parse_inline_sections(data["footer_sections"] || [])
    }
  end

  defp parse_inline_sections(section_list) do
    section_list
    |> Enum.with_index(1)
    |> Enum.map(fn {data, index} ->
      if data["shared_section"] do
        %Section{
          template: :shared_ref,
          position: index,
          fields: %{"__shared_section_ref" => data["shared_section"]}
        }
      else
        %Section{
          template: data["template"],
          position: index,
          fields: data["fields"] || %{}
        }
      end
    end)
  end

  # --- Pages ---

  def read_pages(content_dir) do
    pages_dir = Path.join(content_dir, "pages")

    if File.dir?(pages_dir) do
      pages_dir
      |> find_page_dirs()
      |> Enum.map(&read_page(&1, pages_dir))
      |> Enum.sort_by(& &1.slug)
    else
      []
    end
  end

  defp find_page_dirs(pages_dir) do
    pages_dir
    |> Path.join("**/page.yml")
    |> Path.wildcard()
    |> Enum.map(&Path.dirname/1)
  end

  defp read_page(page_dir, pages_dir) do
    {:ok, data} = read_yaml(Path.join(page_dir, "page.yml"))
    sections = read_sections(Path.join(page_dir, "sections"))
    derived_slug = derive_slug(page_dir, pages_dir)

    %Page{
      slug: data["slug"] || derived_slug,
      title: data["title"],
      meta_title: data["meta_title"],
      meta_description: data["meta_description"],
      og_title: data["og_title"],
      og_description: data["og_description"],
      og_image: data["og_image"],
      layout: data["layout"],
      sections: sections,
      authors: data["authors"] || [],
      tags: data["tags"] || [],
      extra: data["extra"]
    }
  end

  defp derive_slug(page_dir, pages_dir) do
    relative = Path.relative_to(page_dir, pages_dir)

    case relative do
      "index" -> "/"
      path -> "/" <> path
    end
  end

  # --- Shared section resolution ---

  @doc """
  Resolves shared section references in a list of sections.
  Takes a map of shared section name => %SharedSection{}.
  """
  def resolve_sections(sections, shared_map) do
    Enum.map(sections, fn %Section{} = section ->
      case section.fields do
        %{"__shared_section_ref" => ref_name} ->
          case Map.get(shared_map, ref_name) do
            %SharedSection{} = shared ->
              %Section{section | template: shared.template, fields: shared.fields}

            nil ->
              section
          end

        _ ->
          section
      end
    end)
  end

  # --- YAML helpers ---

  defp read_yaml(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, data} -> {:ok, data}
      {:error, _} = err -> err
    end
  end

  # --- Markdown helpers ---

  defp read_markdown(path) do
    content = File.read!(path)

    case String.split(content, ~r/\n---\n/, parts: 2) do
      ["---" <> yaml, body] ->
        {:ok, frontmatter} = YamlElixir.read_from_string(yaml)
        {frontmatter, String.trim(body)}

      _ ->
        {%{}, String.trim(content)}
    end
  end

  defp markdown_to_html(markdown) do
    MDEx.to_html!(markdown)
    |> String.trim()
  end
end
