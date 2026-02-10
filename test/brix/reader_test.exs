defmodule Brix.ReaderTest do
  use ExUnit.Case, async: true

  alias Brix.{Reader, Site, Author, Tag, Media, SectionTemplate, Section, SharedSection, Layout, Page, Collection}

  @fixtures Path.expand("../fixtures/valid", __DIR__)
  @dummy Path.expand("../fixtures/dummy", __DIR__)

  describe "read_site/1" do
    test "reads site.yml into a Site struct" do
      assert {:ok, site} = Reader.read_site(@fixtures)
      assert %Site{} = site
      assert site.name == "Test Site"
      assert site.tagline == "A test site"
      assert site.meta_title == "Test | Site"
      assert site.meta_description == "A site for testing"
      assert site.domain == "test.dev"
    end

    test "returns error for missing site.yml" do
      assert {:error, _reason} = Reader.read_site("/nonexistent")
    end
  end

  describe "read_authors/1" do
    test "reads all authors from authors/ directory" do
      authors = Reader.read_authors(@fixtures)
      assert length(authors) == 2

      jeff = Enum.find(authors, &(&1.slug == "jeff"))
      assert %Author{} = jeff
      assert jeff.name == "Jeff"
      assert jeff.bio == "Builds things with Elixir."
      assert jeff.avatar == "headshot"
      assert jeff.url == "https://jeff.dev"

      sarah = Enum.find(authors, &(&1.slug == "sarah"))
      assert sarah.name == "Sarah"
      assert sarah.avatar == nil
    end

    test "returns empty list when no authors directory" do
      assert Reader.read_authors("/nonexistent") == []
    end
  end

  describe "read_tags/1" do
    test "reads all tags from tags/ directory" do
      tags = Reader.read_tags(@fixtures)
      assert length(tags) == 2

      elixir = Enum.find(tags, &(&1.slug == "elixir"))
      assert %Tag{} = elixir
      assert elixir.display_name == "Elixir"
    end

    test "returns empty list when no tags directory" do
      assert Reader.read_tags("/nonexistent") == []
    end
  end

  describe "read_media/1" do
    test "reads all media from media/ directory" do
      media_list = Reader.read_media(@fixtures)
      assert length(media_list) == 1

      headshot = hd(media_list)
      assert %Media{} = headshot
      assert headshot.slug == "headshot"
      assert headshot.alt == "Photo of Jeff"
      assert headshot.caption == "At the beach"
      assert headshot.content_type == "image/jpeg"
      assert headshot.path == "files/headshot.jpg"
    end

    test "returns empty list when no media directory" do
      assert Reader.read_media("/nonexistent") == []
    end
  end

  describe "read_section_templates/1" do
    test "reads all section templates" do
      templates = Reader.read_section_templates(@fixtures)
      assert length(templates) == 4

      hero = Enum.find(templates, &(&1.name == "hero"))
      assert %SectionTemplate{} = hero
      assert hero.fields["heading"].type == :string
      assert hero.fields["heading"].required == true
      assert hero.fields["subheading"].type == :string
      assert hero.fields["subheading"].required == false
      assert hero.fields["image"].type == :media

      richtext = Enum.find(templates, &(&1.name == "richtext"))
      assert richtext.fields["body"].type == :richtext
      assert richtext.fields["body"].required == true
    end

    test "returns empty list when no templates directory" do
      assert Reader.read_section_templates("/nonexistent") == []
    end
  end

  describe "read_sections/1" do
    test "reads YAML section files" do
      sections_dir = Path.join(@fixtures, "pages/index/sections")
      sections = Reader.read_sections(sections_dir)

      hero = Enum.find(sections, &(&1.template == "hero"))
      assert %Section{} = hero
      assert hero.position == 1
      assert hero.fields["heading"] == "Hello, I'm Jeff"
      assert hero.fields["image"] == "headshot"
    end

    test "reads markdown section files" do
      sections_dir = Path.join(@fixtures, "pages/index/sections")
      sections = Reader.read_sections(sections_dir)

      about = Enum.find(sections, &(&1.template == "richtext"))
      assert %Section{} = about
      assert about.position == 2
      assert about.fields["body"] =~ "bold"
      assert about.fields["body"] =~ "<strong>"
    end

    test "orders sections by position prefix" do
      sections_dir = Path.join(@fixtures, "pages/index/sections")
      sections = Reader.read_sections(sections_dir)

      assert length(sections) == 2
      assert Enum.at(sections, 0).position == 1
      assert Enum.at(sections, 1).position == 2
    end

    test "returns empty list for missing directory" do
      assert Reader.read_sections("/nonexistent") == []
    end
  end

  describe "read_layouts/1" do
    test "reads layout with header and footer sections" do
      layouts = Reader.read_layouts(@fixtures)
      assert length(layouts) == 1

      default = hd(layouts)
      assert %Layout{} = default
      assert default.name == "default"
      assert length(default.header_sections) == 1
      assert hd(default.header_sections).template == "nav"
      assert hd(default.header_sections).fields["links"] |> length() == 2
      assert length(default.footer_sections) == 1
      assert hd(default.footer_sections).template == "footer"
    end

    test "returns empty list when no layouts directory" do
      assert Reader.read_layouts("/nonexistent") == []
    end
  end

  describe "read_pages/1" do
    test "reads pages with metadata and sections" do
      pages = Reader.read_pages(@fixtures)
      assert length(pages) == 2

      home = Enum.find(pages, &(&1.slug == "/"))
      assert %Page{} = home
      assert home.title == "Home"
      assert home.layout == "default"
      assert home.meta_title == "Test | Home"
      assert home.authors == ["jeff"]
      assert home.tags == ["elixir"]
      assert length(home.sections) == 2
    end

    test "derives slug from directory path" do
      pages = Reader.read_pages(@fixtures)

      blog_post = Enum.find(pages, &(&1.title == "Hello World"))
      assert blog_post.slug == "/blog/hello-world"
    end

    test "explicit slug in page.yml overrides derived slug" do
      pages = Reader.read_pages(@fixtures)

      home = Enum.find(pages, &(&1.title == "Home"))
      assert home.slug == "/"
    end

    test "returns empty list when no pages directory" do
      assert Reader.read_pages("/nonexistent") == []
    end
  end

  describe "read_shared_sections/1" do
    test "reads all shared sections" do
      shared = Reader.read_shared_sections(@dummy)
      assert length(shared) == 2
    end

    test "parses shared section fields" do
      shared = Reader.read_shared_sections(@dummy)
      nav = Enum.find(shared, &(&1.name == "main-nav"))

      assert %SharedSection{} = nav
      assert nav.template == "nav"
      assert length(nav.fields["links"]) == 4
    end

    test "returns empty list when no shared_sections directory" do
      assert Reader.read_shared_sections(@fixtures) == []
    end
  end

  describe "resolve_sections/2" do
    test "resolves shared section references" do
      shared_map = %{
        "main-nav" => %SharedSection{
          name: "main-nav",
          template: "nav",
          fields: %{"links" => [%{"label" => "Home", "url" => "/"}]}
        }
      }

      sections = [
        %Section{template: :shared_ref, position: 1, fields: %{"__shared_section_ref" => "main-nav"}},
        %Section{template: "hero", position: 2, fields: %{"heading" => "Hello"}}
      ]

      resolved = Reader.resolve_sections(sections, shared_map)

      assert hd(resolved).template == "nav"
      assert hd(resolved).fields["links"] == [%{"label" => "Home", "url" => "/"}]
      assert hd(resolved).position == 1
      assert List.last(resolved).template == "hero"
    end

    test "leaves unresolved references intact" do
      sections = [
        %Section{template: :shared_ref, position: 1, fields: %{"__shared_section_ref" => "missing"}}
      ]

      resolved = Reader.resolve_sections(sections, %{})
      assert hd(resolved).template == :shared_ref
    end
  end

  describe "read_collections/1" do
    test "reads all collections from collections/ directory" do
      collections = Reader.read_collections(@dummy)
      assert length(collections) == 2
    end

    test "parses collection fields" do
      collections = Reader.read_collections(@dummy)
      blog = Enum.find(collections, &(&1.slug == "blog"))

      assert %Collection{} = blog
      assert blog.name == "Blog"
      assert blog.filters == %{prefix: "/blog/"}
      assert blog.sort_by == "slug"
      assert blog.sort_direction == :asc
      assert blog.meta_title == "Blog | Ember & Bloom"
      assert blog.meta_description == "Thoughts on coffee, craft, and slowing down."
    end

    test "parses desc sort direction" do
      collections = Reader.read_collections(@dummy)
      coffee = Enum.find(collections, &(&1.slug == "coffee-reads"))

      assert coffee.sort_direction == :desc
      assert coffee.filters == %{tag: "coffee"}
    end

    test "returns empty list when no collections directory" do
      assert Reader.read_collections("/nonexistent") == []
    end

    test "returns empty list for fixtures without collections" do
      assert Reader.read_collections(@fixtures) == []
    end
  end
end
