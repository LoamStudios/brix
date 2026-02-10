defmodule Brix.SectionTemplate do
  @moduledoc """
  Defines the field schema for a section type. Used by the validator
  to check that section content matches the expected structure.
  """

  defstruct [:name, :fields]

  @type field_def :: %{
          type: atom(),
          required: boolean(),
          of: atom() | [String.t()] | nil
        }

  @type t :: %__MODULE__{
          name: String.t() | nil,
          fields: %{String.t() => field_def()} | nil
        }
end
