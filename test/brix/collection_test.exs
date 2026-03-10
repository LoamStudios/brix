defmodule Brix.CollectionTest do
  use ExUnit.Case, async: true

  alias Brix.Collection
  alias Brix.Collection.{FilterGroup, Condition}

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

  test "new fields default correctly" do
    collection = %Collection{slug: "test", name: "Test"}

    assert collection.parent == nil
    assert collection.published_at == nil
    assert collection.description == nil
    assert collection.filter_groups == nil
    assert collection.group_logic == :and
  end

  test "creates with advanced fields" do
    collection = %Collection{
      slug: "coffee-by-maya",
      name: "Coffee by Maya",
      description: "Posts about coffee by Maya",
      parent: "blog",
      published_at: ~U[2025-01-15 10:00:00Z],
      filter_groups: [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :tag, value: ["coffee"]},
            %Condition{type: :author, value: ["maya"]}
          ]
        }
      ],
      group_logic: :or
    }

    assert collection.description == "Posts about coffee by Maya"
    assert collection.parent == "blog"
    assert collection.published_at == ~U[2025-01-15 10:00:00Z]
    assert collection.group_logic == :or
    assert length(collection.filter_groups) == 1

    [group] = collection.filter_groups
    assert group.logic == :and
    assert length(group.conditions) == 2
  end

  describe "published?/1" do
    test "returns true when published_at is nil (default visible)" do
      assert Collection.published?(%Collection{published_at: nil})
    end

    test "returns true when published_at is in the past" do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      assert Collection.published?(%Collection{published_at: past})
    end

    test "returns false when published_at is in the future" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      refute Collection.published?(%Collection{published_at: future})
    end
  end
end
