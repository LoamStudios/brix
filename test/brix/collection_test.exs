defmodule Brix.CollectionTest do
  use ExUnit.Case, async: true

  alias Brix.Collection

  test "creates with all fields" do
    collection = %Collection{
      slug: "blog",
      name: "Blog",
      filters: %{prefix: "/blog/"},
      sort_by: "slug",
      sort_direction: :asc,
      meta_title: "Blog | My Site",
      meta_description: "All the posts.",
      extra: %{"icon" => "pencil"}
    }

    assert collection.slug == "blog"
    assert collection.name == "Blog"
    assert collection.filters == %{prefix: "/blog/"}
    assert collection.sort_by == "slug"
    assert collection.sort_direction == :asc
    assert collection.extra["icon"] == "pencil"
  end
end
