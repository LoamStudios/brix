defmodule Brix.Page do
  @moduledoc """
  A content page. Has a slug, metadata, sections, and references
  to a layout, authors, and tags.
  """

  defstruct [:slug, :title, :meta_title, :meta_description,
             :og_title, :og_description, :og_image,
             :layout, :sections, :authors, :tags,
             :published_at, :slug_history, :extra]

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          title: String.t() | nil,
          meta_title: String.t() | nil,
          meta_description: String.t() | nil,
          og_title: String.t() | nil,
          og_description: String.t() | nil,
          og_image: String.t() | nil,
          layout: String.t() | nil,
          sections: [Brix.Section.t()] | nil,
          authors: [String.t()] | nil,
          tags: [String.t()] | nil,
          published_at: DateTime.t() | nil,
          slug_history: [String.t()] | nil,
          extra: map() | nil
        }

  @doc """
  Returns true if the page is published (published_at is set and not in the future).
  """
  def published?(%__MODULE__{published_at: nil}), do: false

  def published?(%__MODULE__{published_at: published_at}) do
    DateTime.compare(published_at, DateTime.utc_now()) != :gt
  end

  @doc """
  Returns true if the page matches the given search query.
  Searches title, meta_description, and all section string fields.
  HTML tags are stripped from richtext fields before matching.
  Case-insensitive. Blank queries match everything.
  """
  def matches?(%__MODULE__{} = _page, query) when query in ["", nil], do: true

  def matches?(%__MODULE__{} = page, query) when is_binary(query) do
    query = String.trim(query)
    if query == "", do: true, else: do_match?(page, String.downcase(query))
  end

  defp do_match?(page, query) do
    searchable_text(page)
    |> String.downcase()
    |> String.contains?(query)
  end

  defp searchable_text(page) do
    meta = [page.title, page.meta_description] |> Enum.reject(&is_nil/1)
    section_texts = page.sections |> List.wrap() |> Enum.flat_map(&section_text/1)
    Enum.join(meta ++ section_texts, " ")
  end

  defp section_text(section) do
    section.fields
    |> Enum.flat_map(fn
      {_key, value} when is_binary(value) -> [strip_html(value)]
      _ -> []
    end)
  end

  defp strip_html(text) do
    text
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
