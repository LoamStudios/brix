defmodule Brix do
  @moduledoc """
  Structured content layer for Phoenix apps.

  Brix models content as **pages** composed of **sections**, each rendered by a
  named template. Pages live inside **layouts** that provide shared header/footer
  sections, and can reference **authors**, **tags**, **media**, and **collections**.

  All functions delegate to the configured store backend:

      config :brix, store: Brix.Store.Filesystem
  """

  defp store, do: Application.fetch_env!(:brix, :store)

  @doc "Returns the site configuration."
  @spec get_site() :: Brix.Site.t()
  def get_site, do: store().get_site()

  @doc """
  Fetches a page by slug.

  ## Options

    * `:status` — filter by publish status: `:published`, `:draft`, or `:all` (default `:published`)
    * `:prefix` — match pages whose slug starts with the given prefix
  """
  @spec get_page(String.t(), keyword()) :: {:ok, Brix.Page.t()} | :error
  def get_page(slug, opts \\ []), do: store().get_page(slug, opts)

  @doc """
  Lists pages.

  ## Options

    * `:status` — filter by publish status: `:published`, `:draft`, or `:all` (default `:published`)
    * `:prefix` — match pages whose slug starts with the given prefix
  """
  @spec list_pages(keyword()) :: [Brix.Page.t()]
  def list_pages(opts \\ []), do: store().list_pages(opts)

  @doc "Fetches a layout by name."
  @spec get_layout(String.t()) :: {:ok, Brix.Layout.t()} | :error
  def get_layout(name), do: store().get_layout(name)

  @doc "Fetches an author by slug."
  @spec get_author(String.t()) :: {:ok, Brix.Author.t()} | :error
  def get_author(slug), do: store().get_author(slug)

  @doc "Lists all authors."
  @spec list_authors() :: [Brix.Author.t()]
  def list_authors, do: store().list_authors()

  @doc "Fetches a tag by slug."
  @spec get_tag(String.t()) :: {:ok, Brix.Tag.t()} | :error
  def get_tag(slug), do: store().get_tag(slug)

  @doc "Lists all tags."
  @spec list_tags() :: [Brix.Tag.t()]
  def list_tags, do: store().list_tags()

  @doc "Fetches a media asset by slug."
  @spec get_media(String.t()) :: {:ok, Brix.Media.t()} | :error
  def get_media(slug), do: store().get_media(slug)

  @doc "Lists all media assets."
  @spec list_media() :: [Brix.Media.t()]
  def list_media, do: store().list_media()

  @doc "Looks up a redirect target for a legacy slug. Returns the new slug or `:error`."
  @spec find_redirect(String.t()) :: {:ok, String.t()} | :error
  def find_redirect(old_slug), do: store().find_redirect(old_slug)

  @doc "Fetches a shared section by name."
  @spec get_shared_section(String.t()) :: {:ok, Brix.SharedSection.t()} | :error
  def get_shared_section(name), do: store().get_shared_section(name)

  @doc "Lists all shared sections."
  @spec list_shared_sections() :: [Brix.SharedSection.t()]
  def list_shared_sections, do: store().list_shared_sections()

  @doc "Fetches a collection by slug."
  @spec get_collection(String.t()) :: {:ok, Brix.Collection.t()} | :error
  def get_collection(slug), do: store().get_collection(slug)

  @doc "Lists all collections."
  @spec list_collections() :: [Brix.Collection.t()]
  def list_collections, do: store().list_collections()

  @doc "Lists child collections whose `parent` matches the given slug."
  @spec list_child_collections(String.t()) :: [Brix.Collection.t()]
  def list_child_collections(parent_slug), do: store().list_child_collections(parent_slug)

  @doc """
  Lists pages belonging to a collection, applying its filters and sort order.

  ## Options

    * `:status` — filter by publish status: `:published`, `:draft`, or `:all` (default `:published`)
  """
  @spec list_collection_pages(Brix.Collection.t(), keyword()) :: [Brix.Page.t()]
  def list_collection_pages(collection, opts \\ []),
    do: store().list_collection_pages(collection, opts)

  @doc "Fetches a section template by name."
  @spec get_section_template(String.t()) :: {:ok, Brix.SectionTemplate.t()} | :error
  def get_section_template(name), do: store().get_section_template(name)

  @doc "Lists all section templates."
  @spec list_section_templates() :: [Brix.SectionTemplate.t()]
  def list_section_templates, do: store().list_section_templates()

  @doc "Reloads all content from the store backend."
  @spec reload() :: :ok | {:error, term()}
  def reload, do: store().reload()
end
