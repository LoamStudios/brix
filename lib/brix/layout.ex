defmodule Brix.Layout do
  @moduledoc """
  A page layout with header and footer sections.
  """

  defstruct [:name, :header_sections, :footer_sections]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          header_sections: [Brix.Section.t()] | nil,
          footer_sections: [Brix.Section.t()] | nil
        }
end
