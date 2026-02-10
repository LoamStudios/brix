defmodule Brix.Validator.Issue do
  @moduledoc """
  A validation issue found in the content tree.
  Severity `:error` blocks loading, `:warning` does not.
  """

  defstruct [:path, :severity, :type, :message]

  @type t :: %__MODULE__{
          path: String.t(),
          severity: :error | :warning,
          type: atom(),
          message: String.t()
        }
end
