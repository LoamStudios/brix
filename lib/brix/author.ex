defmodule Brix.Author do
  @moduledoc """
  A content author. Avatar references a media slug.
  """

  defstruct [:slug, :name, :bio, :avatar, :url, :extra]

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          name: String.t() | nil,
          bio: String.t() | nil,
          avatar: String.t() | nil,
          url: String.t() | nil,
          extra: map() | nil
        }
end
