defmodule Brix.Site do
  @moduledoc """
  Site-wide settings: name, metadata, SEO defaults.
  """

  defstruct [
    :name,
    :tagline,
    :meta_title,
    :meta_description,
    :og_image,
    :favicon,
    :domain,
    :extra
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          tagline: String.t() | nil,
          meta_title: String.t() | nil,
          meta_description: String.t() | nil,
          og_image: String.t() | nil,
          favicon: String.t() | nil,
          domain: String.t() | nil,
          extra: map() | nil
        }
end
