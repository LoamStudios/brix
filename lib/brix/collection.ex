defmodule Brix.Collection do
  @moduledoc """
  A named, filterable grouping of pages. Defined as a YAML file in
  `collections/`, resolved to matching pages at query time.

  ## Simple format

  Collections can use flat `filters:` for common cases:

      name: Blog
      filters:
        prefix: /blog/
        tag: coffee

  ## Advanced format

  For complex logic, use `filter_groups:` with AND/OR conditions:

      name: Coffee by Maya
      filter_groups:
        - logic: and
          conditions:
            - type: tag
              value: [coffee, tea]
            - type: author
              value: maya
      group_logic: or

  The simple `filters:` format is normalized into a single AND group internally.
  """

  alias Brix.Collection.FilterGroup

  defstruct [:slug, :name, :description, :parent, :published_at,
             :filters, :filter_groups, :sort_by, :sort_direction,
             :meta_title, :meta_description,
             :og_title, :og_description, :og_image, :extra,
             group_logic: :and]

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          parent: String.t() | nil,
          published_at: DateTime.t() | nil,
          filters: map() | nil,
          filter_groups: [FilterGroup.t()],
          group_logic: :and | :or,
          sort_by: String.t() | nil,
          sort_direction: :asc | :desc | nil,
          meta_title: String.t() | nil,
          meta_description: String.t() | nil,
          og_title: String.t() | nil,
          og_description: String.t() | nil,
          og_image: String.t() | nil,
          extra: map() | nil
        }

  @doc """
  Returns true if the collection is published (`published_at` is set and not in the future).
  Collections with no `published_at` are considered published (visible by default).
  """
  @spec published?(t()) :: boolean()
  def published?(%__MODULE__{published_at: nil}), do: true

  def published?(%__MODULE__{published_at: published_at}) do
    DateTime.compare(published_at, DateTime.utc_now()) != :gt
  end
end
