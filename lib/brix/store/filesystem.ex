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
  def get_page(slug) do
    case :ets.lookup(__MODULE__, {:page, slug}) do
      [{{:page, _}, page}] -> {:ok, page}
      [] -> :error
    end
  end

  @impl Brix.Store
  def list_pages do
    :ets.match_object(__MODULE__, {{:page, :_}, :_})
    |> Enum.map(fn {_key, page} -> page end)
    |> Enum.sort_by(& &1.slug)
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

    # Pages
    for page <- Reader.read_pages(content_dir) do
      :ets.insert(table, {{:page, page.slug}, page})
    end

    # Layouts
    for layout <- Reader.read_layouts(content_dir) do
      :ets.insert(table, {{:layout, layout.name}, layout})
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

    # Section Templates
    for template <- Reader.read_section_templates(content_dir) do
      :ets.insert(table, {{:section_template, template.name}, template})
    end
  end
end
