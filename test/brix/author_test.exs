defmodule Brix.AuthorTest do
  use ExUnit.Case, async: true

  alias Brix.Author

  test "creates with all fields" do
    author = %Author{
      slug: "jeff",
      name: "Jeff",
      bio: "Builds things with Elixir.",
      avatar: "headshot",
      url: "https://jeff.dev",
      extra: %{"twitter" => "@jeff"}
    }

    assert author.slug == "jeff"
    assert author.name == "Jeff"
    assert author.avatar == "headshot"
    assert author.extra["twitter"] == "@jeff"
  end
end
