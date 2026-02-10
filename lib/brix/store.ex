defmodule Brix.Store do
  @moduledoc """
  Behaviour for Brix content store backends.
  """

  @callback get_site() :: Brix.Site.t()
  @callback get_page(slug :: String.t()) :: {:ok, Brix.Page.t()} | :error
  @callback list_pages(opts :: keyword()) :: [Brix.Page.t()]
  @callback get_layout(name :: String.t()) :: {:ok, Brix.Layout.t()} | :error
  @callback get_author(slug :: String.t()) :: {:ok, Brix.Author.t()} | :error
  @callback list_authors() :: [Brix.Author.t()]
  @callback get_tag(slug :: String.t()) :: {:ok, Brix.Tag.t()} | :error
  @callback list_tags() :: [Brix.Tag.t()]
  @callback get_media(slug :: String.t()) :: {:ok, Brix.Media.t()} | :error
  @callback list_media() :: [Brix.Media.t()]
  @callback get_shared_section(name :: String.t()) :: {:ok, Brix.SharedSection.t()} | :error
  @callback list_shared_sections() :: [Brix.SharedSection.t()]
  @callback get_collection(slug :: String.t()) :: {:ok, Brix.Collection.t()} | :error
  @callback list_collections() :: [Brix.Collection.t()]
  @callback list_collection_pages(collection :: Brix.Collection.t()) :: [Brix.Page.t()]
  @callback get_section_template(name :: String.t()) :: {:ok, Brix.SectionTemplate.t()} | :error
  @callback list_section_templates() :: [Brix.SectionTemplate.t()]
end
