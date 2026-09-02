defmodule Brix.Collection.FilterEngine do
  @moduledoc """
  Evaluates filter groups against a list of pages.

  Used by `Brix.Store.Filesystem.list_collection_pages/1` to apply
  advanced collection filters. Pure function — no ETS dependency.
  """

  alias Brix.Collection.{Condition, FilterGroup}
  alias Brix.Page

  @doc """
  Filters pages by evaluating filter groups with the given group logic.

  Returns all pages when `filter_groups` is empty or nil.

  ## Group logic

    * `:and` — page must pass ALL groups
    * `:or` — page must pass ANY group

  Within each group, conditions combine according to the group's `logic` field.
  """
  @spec evaluate([Page.t()], [FilterGroup.t()] | nil, :and | :or) :: [Page.t()]
  def evaluate(pages, nil, _group_logic), do: pages
  def evaluate(pages, [], _group_logic), do: pages

  def evaluate(pages, filter_groups, group_logic) do
    Enum.filter(pages, fn page ->
      results = Enum.map(filter_groups, &evaluate_group(page, &1))

      case group_logic do
        :and -> Enum.all?(results)
        :or -> Enum.any?(results)
      end
    end)
  end

  defp evaluate_group(page, %FilterGroup{logic: logic, conditions: conditions}) do
    results = Enum.map(conditions, &evaluate_condition(page, &1))

    case logic do
      :and -> Enum.all?(results)
      :or -> Enum.any?(results)
    end
  end

  defp evaluate_condition(page, %Condition{type: :tag, value: values}) do
    Enum.any?(values, fn v -> v in (page.tags || []) end)
  end

  defp evaluate_condition(page, %Condition{type: :author, value: values}) do
    Enum.any?(values, fn v -> v in (page.authors || []) end)
  end

  defp evaluate_condition(page, %Condition{type: :prefix, value: values}) do
    Enum.any?(values, fn prefix ->
      prefix = if String.ends_with?(prefix, "/"), do: prefix, else: prefix <> "/"
      String.starts_with?(page.slug, prefix)
    end)
  end

  defp evaluate_condition(page, %Condition{type: :status, value: values}) do
    published = Page.published?(page)

    Enum.any?(values, fn
      "published" -> published
      "draft" -> not published
      _ -> false
    end)
  end

  defp evaluate_condition(page, %Condition{type: :published_after, value: values}) do
    compare_published_at(page.published_at, values, :lt)
  end

  defp evaluate_condition(page, %Condition{type: :published_before, value: values}) do
    compare_published_at(page.published_at, values, :gt)
  end

  defp evaluate_condition(_page, %Condition{}), do: true

  # True when the page has a published_at that compares favourably against every
  # parseable value. Unparseable values are ignored; an unpublished page fails.
  defp compare_published_at(nil, _values, _excluded), do: false

  defp compare_published_at(published_at, values, excluded) do
    Enum.all?(values, &within_bound?(published_at, &1, excluded))
  end

  defp within_bound?(published_at, value, excluded) do
    case parse_datetime(value) do
      nil -> true
      dt -> DateTime.compare(published_at, dt) != excluded
    end
  end

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} ->
        dt

      {:error, _} ->
        case Date.from_iso8601(str) do
          {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          {:error, _} -> nil
        end
    end
  end

  defp parse_datetime(_), do: nil
end
