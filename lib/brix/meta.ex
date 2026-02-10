defmodule Brix.Meta do
  @moduledoc """
  SEO metadata helpers with page/collection → site fallback.
  """

  @doc """
  Returns the resolved value for the given metadata field,
  falling back from the resource (Page or Collection) to the Site.

  Supported fields: `:title`, `:description`, `:og_title`, `:og_description`, `:og_image`.
  """
  def field(resource, site, :title) do
    resource.meta_title || display_name(resource) || site.meta_title || site.name
  end

  def field(resource, site, :description) do
    resource.meta_description || site.meta_description
  end

  def field(resource, site, :og_title) do
    resource.og_title || field(resource, site, :title)
  end

  def field(resource, site, :og_description) do
    resource.og_description || field(resource, site, :description)
  end

  def field(resource, site, :og_image) do
    resource.og_image || site.og_image
  end

  defp display_name(%{title: title}), do: title
  defp display_name(%{name: name}), do: name
  defp display_name(_), do: nil
end
