defmodule Brix.Page do
  @moduledoc """
  A content page. Has a slug, metadata, sections, and references
  to a layout, authors, and tags.
  """

  defstruct [
    :slug,
    :title,
    :meta_title,
    :meta_description,
    :og_title,
    :og_description,
    :og_image,
    :layout,
    :sections,
    :authors,
    :tags,
    :published_at,
    :updated_at,
    :published_version,
    :versions,
    :slug_history,
    :extra
  ]

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
          updated_at: DateTime.t() | nil,
          published_version: DateTime.t() | nil,
          versions: [Brix.Version.t()] | nil,
          slug_history: [String.t()] | nil,
          extra: map() | nil
        }

  @doc """
  Returns true if the page is published (published_at is set and not in the future).
  """
  @spec published?(t()) :: boolean()
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
  @spec matches?(t(), String.t() | nil) :: boolean()
  def matches?(%__MODULE__{} = _page, query) when query in ["", nil], do: true

  def matches?(%__MODULE__{} = page, query) when is_binary(query) do
    query = String.trim(query)
    if query == "", do: true, else: do_match?(page, String.downcase(query))
  end

  @doc """
  Returns a plain-text excerpt from the page's prose, truncated to
  `:length` characters (default 200). HTML tags are stripped and
  whitespace is normalized. Appends "…" when truncated.

  Only prose fields contribute. By default (`fields: :richtext`) those
  are the fields the section's template declares as `type: richtext`,
  looked up through the configured store; sections whose template is
  unknown contribute nothing. Pass `fields: ["body", "summary"]` to
  name the prose fields explicitly instead, with no template lookup.

  Sections are walked in order, children depth first.

  An integer second argument is shorthand for `length:`.
  """
  @spec excerpt(t(), keyword() | non_neg_integer()) :: String.t()
  def excerpt(page, opts \\ [])

  def excerpt(%__MODULE__{} = page, length) when is_integer(length) do
    excerpt(page, length: length)
  end

  def excerpt(%__MODULE__{} = page, opts) when is_list(opts) do
    length = Keyword.get(opts, :length, 200)
    fields = Keyword.get(opts, :fields, :richtext)

    text =
      page.sections
      |> List.wrap()
      |> Enum.flat_map(&prose_text(&1, fields))
      |> Enum.join(" ")

    if String.length(text) > length do
      text
      |> String.slice(0, length)
      |> String.replace(~r/\s+\S*$/, "")
      |> Kernel.<>("…")
    else
      text
    end
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
    own_texts =
      section.fields
      |> Enum.flat_map(fn
        {_key, value} when is_binary(value) -> [strip_html(value)]
        _ -> []
      end)

    children = section.children || %{}

    child_texts =
      children
      |> Enum.flat_map(fn {_field, child_sections} ->
        Enum.flat_map(child_sections, &section_text/1)
      end)

    own_texts ++ child_texts
  end

  defp prose_text(section, fields) do
    values = section.fields || %{}

    own_texts =
      section
      |> prose_field_names(fields)
      |> Enum.flat_map(fn name ->
        case Map.get(values, name) do
          value when is_binary(value) -> [strip_html(value)]
          _ -> []
        end
      end)

    child_texts =
      (section.children || %{})
      |> Enum.flat_map(fn {_field, child_sections} ->
        Enum.flat_map(child_sections, &prose_text(&1, fields))
      end)

    own_texts ++ child_texts
  end

  defp prose_field_names(_section, names) when is_list(names), do: names

  defp prose_field_names(%{template: name}, :richtext) when is_binary(name) do
    case section_template(name) do
      {:ok, %{fields: fields}} when is_map(fields) ->
        fields
        |> Enum.filter(fn {_name, def} -> def[:type] == :richtext end)
        |> Enum.map(fn {name, _def} -> name end)
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp prose_field_names(_section, :richtext), do: []

  defp section_template(name) do
    case Application.get_env(:brix, :store) do
      nil -> :error
      store -> store.get_section_template(name)
    end
  end

  defp strip_html(text) do
    text
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
