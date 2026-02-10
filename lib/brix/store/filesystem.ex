defmodule Brix.Store.Filesystem do
  @moduledoc """
  File-based content store. Reads from a conventional directory layout,
  validates, and caches everything in ETS for fast concurrent reads.
  """

  @behaviour Brix.Store
  use GenServer

  alias Brix.{Reader, Validator}

  # --- Client API ---

  def start_link(opts) do
    content_dir = Keyword.fetch!(opts, :content_dir)
    GenServer.start_link(__MODULE__, content_dir, name: __MODULE__)
  end

  @impl Brix.Store
  def get_site do
    [{:site, site}] = :ets.lookup(__MODULE__, :site)
    site
  end

  @impl Brix.Store
  def get_page(slug, opts \\ []) do
    case :ets.lookup(__MODULE__, {:page, slug}) do
      [{{:page, _}, page}] -> resolve_version(page, opts)
      [] -> :error
    end
  end

  defp resolve_version(page, []), do: {:ok, page}

  defp resolve_version(page, opts) do
    case Keyword.get(opts, :version) do
      nil ->
        {:ok, page}

      version_dt ->
        case Enum.find(page.versions || [], &(&1.version == version_dt)) do
          nil ->
            :error

          version ->
            {:ok, %{page | sections: version.sections, published_at: version.published_at, updated_at: version.updated_at}}
        end
    end
  end

  @impl Brix.Store
  def list_pages(opts \\ []) do
    :ets.match_object(__MODULE__, {{:page, :_}, :_})
    |> Enum.map(fn {_key, page} -> page end)
    |> filter_pages(opts)
    |> Enum.sort_by(& &1.slug)
  end

  defp filter_pages(pages, []), do: pages

  defp filter_pages(pages, [{:tag, tag} | rest]) do
    pages
    |> Enum.filter(&(tag in &1.tags))
    |> filter_pages(rest)
  end

  defp filter_pages(pages, [{:author, author} | rest]) do
    pages
    |> Enum.filter(&(author in &1.authors))
    |> filter_pages(rest)
  end

  defp filter_pages(pages, [{:prefix, prefix} | rest]) do
    # Ensure prefix matching works with or without trailing slash
    prefix = if String.ends_with?(prefix, "/"), do: prefix, else: prefix <> "/"

    pages
    |> Enum.filter(&String.starts_with?(&1.slug, prefix))
    |> filter_pages(rest)
  end

  defp filter_pages(pages, [{:status, :published} | rest]) do
    pages
    |> Enum.filter(&Brix.Page.published?/1)
    |> filter_pages(rest)
  end

  defp filter_pages(pages, [{:status, :draft} | rest]) do
    pages
    |> Enum.reject(&Brix.Page.published?/1)
    |> filter_pages(rest)
  end

  defp filter_pages(_pages, [{key, _value} | _rest]) do
    raise ArgumentError, "unknown filter #{inspect(key)}. Valid filters: :tag, :author, :prefix, :status"
  end

  @impl Brix.Store
  def get_layout(name) do
    case :ets.lookup(__MODULE__, {:layout, name}) do
      [{{:layout, _}, layout}] -> {:ok, layout}
      [] -> :error
    end
  end

  @impl Brix.Store
  def get_author(slug) do
    case :ets.lookup(__MODULE__, {:author, slug}) do
      [{{:author, _}, author}] -> {:ok, author}
      [] -> :error
    end
  end

  @impl Brix.Store
  def list_authors do
    :ets.match_object(__MODULE__, {{:author, :_}, :_})
    |> Enum.map(fn {_key, author} -> author end)
    |> Enum.sort_by(& &1.slug)
  end

  @impl Brix.Store
  def get_tag(slug) do
    case :ets.lookup(__MODULE__, {:tag, slug}) do
      [{{:tag, _}, tag}] -> {:ok, tag}
      [] -> :error
    end
  end

  @impl Brix.Store
  def list_tags do
    :ets.match_object(__MODULE__, {{:tag, :_}, :_})
    |> Enum.map(fn {_key, tag} -> tag end)
    |> Enum.sort_by(& &1.slug)
  end

  @impl Brix.Store
  def get_media(slug) do
    case :ets.lookup(__MODULE__, {:media, slug}) do
      [{{:media, _}, media}] -> {:ok, media}
      [] -> :error
    end
  end

  @impl Brix.Store
  def list_media do
    :ets.match_object(__MODULE__, {{:media, :_}, :_})
    |> Enum.map(fn {_key, media} -> media end)
    |> Enum.sort_by(& &1.slug)
  end

  @impl Brix.Store
  def find_redirect(old_slug) do
    case :ets.lookup(__MODULE__, {:redirect, old_slug}) do
      [{{:redirect, _}, current_slug}] -> {:ok, current_slug}
      [] -> :error
    end
  end

  @impl Brix.Store
  def get_shared_section(name) do
    case :ets.lookup(__MODULE__, {:shared_section, name}) do
      [{{:shared_section, _}, shared}] -> {:ok, shared}
      [] -> :error
    end
  end

  @impl Brix.Store
  def list_shared_sections do
    :ets.match_object(__MODULE__, {{:shared_section, :_}, :_})
    |> Enum.map(fn {_key, shared} -> shared end)
    |> Enum.sort_by(& &1.name)
  end

  @impl Brix.Store
  def get_collection(slug) do
    case :ets.lookup(__MODULE__, {:collection, slug}) do
      [{{:collection, _}, collection}] -> {:ok, collection}
      [] -> :error
    end
  end

  @impl Brix.Store
  def list_collections do
    :ets.match_object(__MODULE__, {{:collection, :_}, :_})
    |> Enum.map(fn {_key, collection} -> collection end)
    |> Enum.sort_by(& &1.slug)
  end

  @impl Brix.Store
  def list_collection_pages(%Brix.Collection{} = collection) do
    filters = collection.filters |> Enum.into([])
    pages = list_pages(filters)

    case collection.sort_by do
      nil -> pages
      field -> sort_pages(pages, field, collection.sort_direction || :asc)
    end
  end

  defp sort_pages(pages, "slug", direction), do: sort_by(pages, & &1.slug, direction)
  defp sort_pages(pages, "title", direction), do: sort_by(pages, & &1.title, direction)
  defp sort_pages(pages, "published_at", direction), do: sort_by(pages, & &1.published_at, direction)
  defp sort_pages(pages, "updated_at", direction), do: sort_by(pages, & &1.updated_at, direction)
  defp sort_pages(pages, _field, _direction), do: pages

  defp sort_by(pages, key_fn, :asc), do: Enum.sort_by(pages, key_fn)
  defp sort_by(pages, key_fn, :desc), do: Enum.sort_by(pages, key_fn, :desc)

  @impl Brix.Store
  def get_section_template(name) do
    case :ets.lookup(__MODULE__, {:section_template, name}) do
      [{{:section_template, _}, template}] -> {:ok, template}
      [] -> :error
    end
  end

  @impl Brix.Store
  def list_section_templates do
    :ets.match_object(__MODULE__, {{:section_template, :_}, :_})
    |> Enum.map(fn {_key, template} -> template end)
    |> Enum.sort_by(& &1.name)
  end

  # --- Server callbacks ---

  @impl GenServer
  def init(content_dir) do
    # Step 1: Validate
    result = Validator.validate(content_dir)

    if result.errors != [] do
      messages = Enum.map(result.errors, fn issue ->
        "  #{issue.path}: #{issue.message}"
      end)

      raise "Brix content validation failed:\n#{Enum.join(messages, "\n")}"
    end

    # Log warnings
    for issue <- result.warnings do
      require Logger
      Logger.warning("Brix: #{issue.path}: #{issue.message}")
    end

    # Step 2: Load into ETS
    table = :ets.new(__MODULE__, [:named_table, :set, read_concurrency: true])
    load_content(table, content_dir)

    {:ok, %{content_dir: content_dir}}
  end

  defp load_content(table, content_dir) do
    # Site
    {:ok, site} = Reader.read_site(content_dir)
    :ets.insert(table, {:site, site})

    # Shared Sections (read first for resolution)
    shared_sections = Reader.read_shared_sections(content_dir)
    shared_map = Map.new(shared_sections, &{&1.name, &1})

    for shared <- shared_sections do
      :ets.insert(table, {{:shared_section, shared.name}, shared})
    end

    # Pages (resolve shared section refs in all versions + build redirect index)
    for page <- Reader.read_pages(content_dir) do
      resolved_versions =
        Enum.map(page.versions || [], fn version ->
          %{version | sections: Reader.resolve_sections(version.sections, shared_map)}
        end)

      resolved_sections = Reader.resolve_sections(page.sections, shared_map)

      resolved = %{page | sections: resolved_sections, versions: resolved_versions}
      :ets.insert(table, {{:page, resolved.slug}, resolved})

      for old_slug <- resolved.slug_history || [] do
        :ets.insert(table, {{:redirect, old_slug}, resolved.slug})
      end
    end

    # Layouts (resolve shared section refs)
    for layout <- Reader.read_layouts(content_dir) do
      resolved = %{layout |
        header_sections: Reader.resolve_sections(layout.header_sections, shared_map),
        footer_sections: Reader.resolve_sections(layout.footer_sections, shared_map)
      }
      :ets.insert(table, {{:layout, resolved.name}, resolved})
    end

    # Authors
    for author <- Reader.read_authors(content_dir) do
      :ets.insert(table, {{:author, author.slug}, author})
    end

    # Tags
    for tag <- Reader.read_tags(content_dir) do
      :ets.insert(table, {{:tag, tag.slug}, tag})
    end

    # Media
    for media <- Reader.read_media(content_dir) do
      :ets.insert(table, {{:media, media.slug}, media})
    end

    # Collections
    for collection <- Reader.read_collections(content_dir) do
      :ets.insert(table, {{:collection, collection.slug}, collection})
    end

    # Section Templates
    for template <- Reader.read_section_templates(content_dir) do
      :ets.insert(table, {{:section_template, template.name}, template})
    end
  end
end
