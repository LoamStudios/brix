defmodule Brix.TagTest do
  use ExUnit.Case, async: true

  alias Brix.Tag

  test "creates with slug and display_name" do
    tag = %Tag{slug: "elixir", display_name: "Elixir"}

    assert tag.slug == "elixir"
    assert tag.display_name == "Elixir"
  end
end
