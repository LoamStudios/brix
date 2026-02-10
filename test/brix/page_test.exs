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
        %Section{template: "hero", position: 1, fields: %{"heading" => "Rise and Grind", "subheading" => "Every day starts here"}},
        %Section{template: "richtext", position: 2, fields: %{"body" => "<p>French press is <strong>forgiving</strong> and produces a full-bodied cup.</p>"}}
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
end
