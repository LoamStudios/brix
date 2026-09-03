defmodule Brix.PageExcerptTest do
  # Exercises the default `fields: :richtext` mode, which looks up
  # section templates through the configured store.
  use ExUnit.Case, async: false

  alias Brix.{Page, Section}

  @valid Path.expand("../fixtures/valid", __DIR__)

  setup do
    Application.put_env(:brix, :store, Brix.Store.Filesystem)
    start_supervised!({Brix.Store.Filesystem, content_dir: @valid})
    :ok
  end

  @page %Page{
    sections: [
      %Section{
        template: "hero",
        position: 1,
        fields: %{"heading" => "Hello, I'm Jeff", "subheading" => "I build things"}
      },
      %Section{template: "mystery", position: 2, fields: %{"body" => "<p>Unknown template.</p>"}},
      %Section{
        template: "richtext",
        position: 3,
        fields: %{"body" => "<p>French press is forgiving and produces a full-bodied cup.</p>"}
      }
    ]
  }

  test "uses only fields the template declares as richtext" do
    assert Page.excerpt(@page) == "French press is forgiving and produces a full-bodied cup."
  end

  test "skips sections whose template is unknown" do
    refute Page.excerpt(@page) =~ "Unknown"
  end

  test "returns an empty string when no section has richtext fields" do
    page = %Page{sections: Enum.take(@page.sections, 1)}
    assert Page.excerpt(page) == ""
  end

  test "an integer second argument sets the length" do
    excerpt = Page.excerpt(@page, 20)
    assert String.ends_with?(excerpt, "…")
    assert String.length(excerpt) <= 25
  end

  test "walks richtext fields in nested sections" do
    page = %Page{
      sections: [
        %Section{
          template: "hero",
          position: 1,
          fields: %{"heading" => "Title"},
          children: %{
            "items" => [
              %Section{template: "richtext", position: 1, fields: %{"body" => "<p>Nested.</p>"}}
            ]
          }
        }
      ]
    }

    assert Page.excerpt(page) == "Nested."
  end
end
