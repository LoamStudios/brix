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
  end
end
