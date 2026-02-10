defmodule Brix.Version do
  @moduledoc """
  A content version. Versions live inside a page's `versions/` directory,
  each identified by a compact ISO timestamp (e.g. `20241001T080000Z`).
  """

  defstruct [:version, :published_at, :updated_at, :sections]

  @type t :: %__MODULE__{
          version: DateTime.t() | nil,
          published_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          sections: [Brix.Section.t()] | nil
        }
end
