defmodule Brix.Store do
  @moduledoc """
  Behaviour for Brix content store backends.

  Implement all callbacks to provide a content store. See `Brix.Store.Filesystem`
  for the built-in flat-file implementation.
  """

  @doc "Returns the site configuration."
  @callback get_site() :: Brix.Site.t()

  @doc """
  Fetches a page by slug.

  ## Options

    * `:status` — filter by publish status: `:published`, `:draft`, or `:all` (default `:published`)
    * `:prefix` — match pages whose slug starts with the given prefix
  """
  @callback get_page(slug :: String.t(), opts :: keyword()) :: {:ok, Brix.Page.t()} | :error

  @doc """
  Lists pages.

  ## Options

    * `:status` — filter by publish status: `:published`, `:draft`, or `:all` (default `:published`)
    * `:prefix` — match pages whose slug starts with the given prefix
  """
  @callback list_pages(opts :: keyword()) :: [Brix.Page.t()]

  @doc "Fetches a layout by name."
  @callback get_layout(name :: String.t()) :: {:ok, Brix.Layout.t()} | :error

  @doc "Fetches an author by slug."
  @callback get_author(slug :: String.t()) :: {:ok, Brix.Author.t()} | :error

  @doc "Lists all authors."
  @callback list_authors() :: [Brix.Author.t()]

  @doc "Fetches a tag by slug."
  @callback get_tag(slug :: String.t()) :: {:ok, Brix.Tag.t()} | :error

  @doc "Lists all tags."
  @callback list_tags() :: [Brix.Tag.t()]

  @doc "Fetches a media asset by slug."
  @callback get_media(slug :: String.t()) :: {:ok, Brix.Media.t()} | :error

  @doc "Lists all media assets."
  @callback list_media() :: [Brix.Media.t()]

  @doc "Looks up a redirect target for a legacy slug. Returns the new slug or `:error`."
  @callback find_redirect(old_slug :: String.t()) :: {:ok, String.t()} | :error

  @doc "Fetches a shared section by name."
  @callback get_shared_section(name :: String.t()) :: {:ok, Brix.SharedSection.t()} | :error

  @doc "Lists all shared sections."
  @callback list_shared_sections() :: [Brix.SharedSection.t()]

  @doc "Fetches a collection by slug."
  @callback get_collection(slug :: String.t()) :: {:ok, Brix.Collection.t()} | :error

  @doc "Lists all collections."
  @callback list_collections() :: [Brix.Collection.t()]

  @doc "Lists child collections whose `parent` matches the given slug."
  @callback list_child_collections(parent_slug :: String.t()) :: [Brix.Collection.t()]

  @doc """
  Lists pages belonging to a collection, applying its filters and sort order.

  ## Options

    * `:status` — filter by publish status: `:published`, `:draft`, or `:all` (default `:published`)
  """
  @callback list_collection_pages(collection :: Brix.Collection.t(), opts :: keyword()) ::
              [Brix.Page.t()]

  @doc "Fetches a section template by name."
  @callback get_section_template(name :: String.t()) :: {:ok, Brix.SectionTemplate.t()} | :error

  @doc "Lists all section templates."
  @callback list_section_templates() :: [Brix.SectionTemplate.t()]

  @doc "Reloads all content from the filesystem (or other backing store)."
  @callback reload() :: :ok | {:error, term()}
end
