defmodule Brix.Collection.FilterEngineTest do
  use ExUnit.Case, async: true

  alias Brix.Collection.{Condition, FilterEngine, FilterGroup}
  alias Brix.Page

  @published_page %Page{
    slug: "/blog/coffee",
    title: "Coffee Post",
    tags: ["coffee", "brewing"],
    authors: ["maya"],
    published_at: ~U[2024-06-15 10:00:00Z]
  }

  @draft_page %Page{
    slug: "/blog/draft",
    title: "Draft Post",
    tags: ["tea"],
    authors: ["jeff"],
    published_at: nil
  }

  @old_page %Page{
    slug: "/articles/old",
    title: "Old Article",
    tags: ["coffee"],
    authors: ["maya", "jeff"],
    published_at: ~U[2023-01-01 00:00:00Z]
  }

  @pages [@published_page, @draft_page, @old_page]

  describe "evaluate/3 basics" do
    test "returns all pages when filter_groups is nil" do
      assert FilterEngine.evaluate(@pages, nil, :and) == @pages
    end

    test "returns all pages when filter_groups is empty" do
      assert FilterEngine.evaluate(@pages, [], :and) == @pages
    end
  end

  describe "single condition" do
    test "tag condition matches pages with that tag" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :tag, value: ["coffee"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/coffee" in slugs
      assert "/articles/old" in slugs
      refute "/blog/draft" in slugs
    end

    test "author condition matches pages with that author" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :author, value: ["jeff"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/draft" in slugs
      assert "/articles/old" in slugs
      refute "/blog/coffee" in slugs
    end

    test "prefix condition matches page slugs" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :prefix, value: ["/blog/"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/coffee" in slugs
      assert "/blog/draft" in slugs
      refute "/articles/old" in slugs
    end

    test "prefix without trailing slash still works" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :prefix, value: ["/blog"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert length(result) == 2
    end

    test "status published matches only published pages" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :status, value: ["published"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/coffee" in slugs
      assert "/articles/old" in slugs
      refute "/blog/draft" in slugs
    end

    test "status draft matches only draft pages" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :status, value: ["draft"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert [%Page{slug: "/blog/draft"}] = result
    end

    test "published_after filters by date" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :published_after, value: ["2024-01-01"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/coffee" in slugs
      refute "/articles/old" in slugs
      refute "/blog/draft" in slugs
    end

    test "published_before filters by date" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :published_before, value: ["2024-01-01"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert [%Page{slug: "/articles/old"}] = result
    end

    test "published_after with ISO datetime" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :published_after, value: ["2024-06-15T10:00:00Z"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert [%Page{slug: "/blog/coffee"}] = result
    end
  end

  describe "multi-value conditions" do
    test "tag with multiple values matches any" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :tag, value: ["tea", "brewing"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/coffee" in slugs
      assert "/blog/draft" in slugs
      refute "/articles/old" in slugs
    end

    test "author with multiple values matches any" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :author, value: ["maya", "jeff"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert length(result) == 3
    end

    test "prefix with multiple values matches any" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :prefix, value: ["/blog/", "/articles/"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert length(result) == 3
    end
  end

  describe "AND group logic" do
    test "all conditions must match within an AND group" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :tag, value: ["coffee"]},
            %Condition{type: :author, value: ["maya"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/coffee" in slugs
      assert "/articles/old" in slugs
      refute "/blog/draft" in slugs
    end

    test "AND group with prefix and tag" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :prefix, value: ["/blog/"]},
            %Condition{type: :tag, value: ["coffee"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert [%Page{slug: "/blog/coffee"}] = result
    end
  end

  describe "OR group logic" do
    test "any condition can match within an OR group" do
      groups = [
        %FilterGroup{
          logic: :or,
          conditions: [
            %Condition{type: :tag, value: ["tea"]},
            %Condition{type: :prefix, value: ["/articles/"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/draft" in slugs
      assert "/articles/old" in slugs
      refute "/blog/coffee" in slugs
    end
  end

  describe "multiple groups with group_logic" do
    test "group_logic :and requires all groups to pass" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :tag, value: ["coffee"]}
          ]
        },
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :prefix, value: ["/blog/"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert [%Page{slug: "/blog/coffee"}] = result
    end

    test "group_logic :or requires any group to pass" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :tag, value: ["tea"]}
          ]
        },
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :prefix, value: ["/articles/"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :or)
      slugs = Enum.map(result, & &1.slug)

      assert "/blog/draft" in slugs
      assert "/articles/old" in slugs
      refute "/blog/coffee" in slugs
    end
  end

  describe "date range" do
    test "published_after and published_before combine for a date range" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :published_after, value: ["2024-01-01"]},
            %Condition{type: :published_before, value: ["2024-12-31"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert [%Page{slug: "/blog/coffee"}] = result
    end
  end

  describe "edge cases" do
    test "unknown condition type passes through" do
      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :unknown, value: ["whatever"]}
          ]
        }
      ]

      result = FilterEngine.evaluate(@pages, groups, :and)
      assert length(result) == 3
    end

    test "page with nil tags doesn't crash on tag condition" do
      page = %Page{slug: "/bare", tags: nil, authors: nil, published_at: nil}

      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :tag, value: ["coffee"]}
          ]
        }
      ]

      assert FilterEngine.evaluate([page], groups, :and) == []
    end

    test "page with nil authors doesn't crash on author condition" do
      page = %Page{slug: "/bare", tags: nil, authors: nil, published_at: nil}

      groups = [
        %FilterGroup{
          logic: :and,
          conditions: [
            %Condition{type: :author, value: ["maya"]}
          ]
        }
      ]

      assert FilterEngine.evaluate([page], groups, :and) == []
    end
  end
end
