defmodule Brix.Meta do
  @moduledoc """
  SEO metadata helpers with page → site fallback.
  """

  alias Brix.{Page, Site}

  @doc """
  Returns the meta title, falling back from page to site.
  """
  def title(%Page{} = page, %Site{} = site) do
    page.meta_title || page.title || site.meta_title || site.name
  end

  @doc """
  Returns the meta description, falling back from page to site.
  """
  def description(%Page{} = page, %Site{} = site) do
    page.meta_description || site.meta_description
  end

  @doc """
  Returns the OG title, falling back through page OG → page meta → site.
  """
  def og_title(%Page{} = page, %Site{} = site) do
    page.og_title || title(page, site)
  end

  @doc """
  Returns the OG description, falling back through page OG → page meta → site.
  """
  def og_description(%Page{} = page, %Site{} = site) do
    page.og_description || description(page, site)
  end

  @doc """
  Returns the OG image, falling back from page to site.
  """
  def og_image(%Page{} = page, %Site{} = site) do
    page.og_image || site.og_image
  end
end
