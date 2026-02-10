defmodule Brix.Collection do
  @moduledoc """
  A named, filterable grouping of pages. Defined as a YAML file in
  `collections/`, resolved to matching pages at query time.
  """

  defstruct [:slug, :name, :filters, :sort_by, :sort_direction,
             :meta_title, :meta_description,
             :og_title, :og_description, :og_image, :extra]

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          name: String.t() | nil,
          filters: map() | nil,
          sort_by: String.t() | nil,
          sort_direction: :asc | :desc | nil,
          meta_title: String.t() | nil,
          meta_description: String.t() | nil,
          og_title: String.t() | nil,
          og_description: String.t() | nil,
          og_image: String.t() | nil,
          extra: map() | nil
        }
end
