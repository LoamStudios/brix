defmodule Brix.Tag do
  @moduledoc """
  A content tag. Slug is the identifier, display_name is for rendering.
  """

  defstruct [:slug, :display_name]

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          display_name: String.t() | nil
        }
end
