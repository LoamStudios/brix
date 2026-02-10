defmodule Brix.Section do
  @moduledoc """
  A content section within a page or layout. Has a template name,
  a position (for ordering), and a map of field values.
  """

  defstruct [:template, :position, :fields]

  @type t :: %__MODULE__{
          template: String.t() | nil,
          position: integer() | nil,
          fields: map() | nil
        }
end
