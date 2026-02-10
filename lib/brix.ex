defmodule Brix do
  @moduledoc """
  Structured content layer for Phoenix apps.

  Delegates to the configured store backend. Configure in your app:

      config :brix, store: Brix.Store.Filesystem
  """

  defp store, do: Application.fetch_env!(:brix, :store)

  def get_site, do: store().get_site()
  def get_page(slug, opts \\ []), do: store().get_page(slug, opts)
  def list_pages(opts \\ []), do: store().list_pages(opts)
  def get_layout(name), do: store().get_layout(name)
  def get_author(slug), do: store().get_author(slug)
  def list_authors, do: store().list_authors()
  def get_tag(slug), do: store().get_tag(slug)
  def list_tags, do: store().list_tags()
  def get_media(slug), do: store().get_media(slug)
  def list_media, do: store().list_media()
  def find_redirect(old_slug), do: store().find_redirect(old_slug)
  def get_shared_section(name), do: store().get_shared_section(name)
  def list_shared_sections, do: store().list_shared_sections()
  def get_collection(slug), do: store().get_collection(slug)
  def list_collections, do: store().list_collections()
  def list_collection_pages(collection), do: store().list_collection_pages(collection)
  def get_section_template(name), do: store().get_section_template(name)
  def list_section_templates, do: store().list_section_templates()
  def reload, do: store().reload()
end
