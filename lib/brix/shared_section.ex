defmodule Brix.SharedSection do
  @moduledoc """
  A reusable content block that can be referenced from page sections
  or layout sections. Defined once in `shared_sections/`, referenced by name.
  """

  defstruct [:name, :template, :fields]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          template: String.t() | nil,
          fields: map() | nil
        }
end
