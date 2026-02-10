defmodule Brix.Media do
  @moduledoc """
  A media asset. Path is relative to the media directory.
  """

  defstruct [:slug, :path, :alt, :caption, :content_type, :extra]

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          path: String.t() | nil,
          alt: String.t() | nil,
          caption: String.t() | nil,
          content_type: String.t() | nil,
          extra: map() | nil
        }
end
