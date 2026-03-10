defmodule Brix.Collection.FilterGroup do
  @moduledoc """
  A group of filter conditions combined with AND or OR logic.

  Collections contain one or more filter groups. Each group holds a list
  of `Brix.Collection.Condition` structs and a `logic` field (`:and` or `:or`)
  that determines how conditions within the group combine.
  """

  alias Brix.Collection.Condition

  defstruct logic: :and, conditions: []

  @type t :: %__MODULE__{
          logic: :and | :or,
          conditions: [Condition.t()]
        }
end

defmodule Brix.Collection.Condition do
  @moduledoc """
  A single filter condition within a filter group.

  ## Condition types

    * `:tag` — page has any of the given tags
    * `:author` — page has any of the given authors
    * `:prefix` — page slug starts with any of the given prefixes
    * `:status` — page publish status (`:published` or `:draft`)
    * `:published_after` — page published_at is on or after the given date
    * `:published_before` — page published_at is on or before the given date

  The `value` field is always a list internally, even for single-value conditions.
  """

  defstruct [:type, value: []]

  @type condition_type :: :tag | :author | :prefix | :status | :published_after | :published_before

  @type t :: %__MODULE__{
          type: condition_type(),
          value: [String.t()]
        }

  @valid_types ~w(tag author prefix status published_after published_before)a

  @doc "Returns the list of valid condition types."
  @spec valid_types() :: [condition_type()]
  def valid_types, do: @valid_types
end
