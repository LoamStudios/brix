defmodule Brix.PageTest do
  use ExUnit.Case, async: true

  alias Brix.{Page, Section}

  test "creates with sections, authors, and tags" do
    page = %Page{
      slug: "/about",
      title: "About",
      meta_title: "About | Jeff",
      meta_description: "About page",
      layout: "default",
      sections: [
        %Section{template: "hero", position: 1, fields: %{"heading" => "Hello"}},
        %Section{template: "richtext", position: 2, fields: %{"body" => "<p>Hi</p>"}}
      ],
      authors: ["jeff"],
      tags: ["elixir", "phoenix"],
      extra: %{"featured" => true}
    }

    assert page.slug == "/about"
    assert length(page.sections) == 2
    assert hd(page.sections).template == "hero"
    assert page.authors == ["jeff"]
    assert page.tags == ["elixir", "phoenix"]
    assert page.extra["featured"] == true
  end

  test "defaults to nil for all fields" do
    page = %Page{}

    assert page.slug == nil
    assert page.sections == nil
    assert page.layout == nil
    assert page.published_at == nil
    assert page.updated_at == nil
    assert page.published_version == nil
    assert page.versions == nil
    assert page.slug_history == nil
  end

  describe "published?/1" do
    test "returns false when published_at is nil" do
      refute Page.published?(%Page{published_at: nil})
    end

    test "returns true when published_at is in the past" do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      assert Page.published?(%Page{published_at: past})
    end

    test "returns false when published_at is in the future" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      refute Page.published?(%Page{published_at: future})
    end

    test "returns true when published_at is right now" do
      # Use a time 1 second in the past to avoid timing edge cases
      now = DateTime.add(DateTime.utc_now(), -1, :second)
      assert Page.published?(%Page{published_at: now})
    end
  end

  describe "matches?/2" do
    @page %Page{
      title: "The Morning Ritual",
      meta_description: "A guide to brewing better coffee at home.",
      sections: [
        %Section{
          template: "hero",
          position: 1,
          fields: %{"heading" => "Rise and Grind", "subheading" => "Every day starts here"}
        },
        %Section{
          template: "richtext",
          position: 2,
          fields: %{
            "body" =>
              "<p>French press is <strong>forgiving</strong> and produces a full-bodied cup.</p>"
          }
        }
      ]
    }

    test "matches page title" do
      assert Page.matches?(@page, "morning")
    end

    test "matches meta_description" do
      assert Page.matches?(@page, "brewing")
    end

    test "matches section string fields" do
      assert Page.matches?(@page, "grind")
    end

    test "matches section body with HTML stripped" do
      assert Page.matches?(@page, "forgiving")
    end

    test "does not match HTML tags" do
      refute Page.matches?(@page, "strong")
    end

    test "is case-insensitive" do
      assert Page.matches?(@page, "MORNING")
      assert Page.matches?(@page, "French Press")
    end

    test "returns false for no match" do
      refute Page.matches?(@page, "espresso")
    end

    test "blank query matches everything" do
      assert Page.matches?(@page, "")
      assert Page.matches?(@page, "  ")
    end

    test "handles page with nil sections" do
      page = %Page{title: "Empty"}
      assert Page.matches?(page, "empty")
      refute Page.matches?(page, "nope")
    end
  end

  describe "excerpt/2" do
    @long_page %Page{
      sections: [
        %Section{template: "hero", position: 1, fields: %{"heading" => "Hello"}},
        %Section{
          template: "richtext",
          position: 2,
          fields: %{
            "body" =>
              "<p>French press is forgiving and produces a full-bodied cup. The grind matters more than the beans.</p>"
          }
        }
      ]
    }

    test "returns plain text from sections with HTML stripped" do
      excerpt = Page.excerpt(@long_page, length: 500, fields: ["body"])
      refute excerpt =~ "<p>"
      assert excerpt =~ "French press"
    end

    test "truncates to specified length on a word boundary" do
      excerpt = Page.excerpt(@long_page, length: 30, fields: ["body"])
      assert String.ends_with?(excerpt, "…")
      assert String.length(excerpt) <= 35
    end

    test "does not truncate when content is shorter than length" do
      excerpt = Page.excerpt(@long_page, length: 500, fields: ["body"])
      refute String.ends_with?(excerpt, "…")
    end

    test "defaults to 200 characters" do
      page = %Page{
        sections: [
          %Section{
            template: "richtext",
            position: 1,
            fields: %{"body" => String.duplicate("word ", 100)}
          }
        ]
      }

      excerpt = Page.excerpt(page, fields: ["body"])
      assert String.ends_with?(excerpt, "…")
      assert String.length(excerpt) <= 205
    end

    test "handles page with nil sections" do
      assert Page.excerpt(%Page{}) == ""
    end

    test "explicit fields ignore every other string field" do
      excerpt = Page.excerpt(@long_page, length: 500, fields: ["body"])
      refute excerpt =~ "Hello"
      assert String.starts_with?(excerpt, "French press")
    end

    test "explicit fields are read from nested sections" do
      page = %Page{
        sections: [
          %Section{
            template: "wrapper",
            position: 1,
            fields: %{"title" => "Chapters"},
            children: %{
              "items" => [
                %Section{template: "chapter", position: 1, fields: %{"body" => "<p>One.</p>"}},
                %Section{template: "chapter", position: 2, fields: %{"body" => "<p>Two.</p>"}}
              ]
            }
          }
        ]
      }

      assert Page.excerpt(page, fields: ["body"]) == "One. Two."
    end
  end

  describe "matches?/2 with nested sections" do
    @nested_page %Page{
      title: "Gallery",
      sections: [
        %Section{
          template: "gallery",
          position: 1,
          fields: %{"title" => "Photo Gallery"},
          children: %{
            "slides" => [
              %Section{template: "slide", position: 1, fields: %{"heading" => "Sunset Beach"}},
              %Section{template: "slide", position: 2, fields: %{"heading" => "Mountain View"}}
            ]
          }
        }
      ]
    }

    test "finds text in nested sections" do
      assert Page.matches?(@nested_page, "sunset")
    end

    test "finds text in parent section" do
      assert Page.matches?(@nested_page, "photo gallery")
    end

    test "does not match absent text" do
      refute Page.matches?(@nested_page, "ocean")
    end
  end

  describe "excerpt/2 with nested sections" do
    test "includes nested section text" do
      page = %Page{
        sections: [
          %Section{
            template: "gallery",
            position: 1,
            fields: %{"title" => "Photos"},
            children: %{
              "slides" => [
                %Section{
                  template: "slide",
                  position: 1,
                  fields: %{"heading" => "Beautiful Sunset"}
                }
              ]
            }
          }
        ]
      }

      excerpt = Page.excerpt(page, length: 500, fields: ["title", "heading"])
      assert excerpt =~ "Photos"
      assert excerpt =~ "Beautiful Sunset"
    end
  end
end
