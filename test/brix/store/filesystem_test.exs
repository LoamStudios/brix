defmodule Brix.Store.FilesystemTest do
  use ExUnit.Case

  alias Brix.Store.Filesystem
  alias Brix.{Site, Page, Layout, Author, Tag, Media, SectionTemplate}

  @valid Path.expand("../../fixtures/valid", __DIR__)
  @dummy Path.expand("../../fixtures/dummy", __DIR__)
  @missing_site Path.expand("../../fixtures/missing_site", __DIR__)

  describe "start_link/1 with valid content" do
    setup do
      store = start_supervised!({Filesystem, content_dir: @valid})
      %{store: store}
    end

    test "starts successfully" do
      assert Process.alive?(Process.whereis(Filesystem))
    end
  end

  describe "get_site/0" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns the site" do
      assert %Site{} = Filesystem.get_site()
      assert Filesystem.get_site().name == "Test Site"
      assert Filesystem.get_site().domain == "test.dev"
    end
  end

  describe "get_page/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns page by slug" do
      assert {:ok, page} = Filesystem.get_page("/")
      assert %Page{} = page
      assert page.title == "Home"
      assert length(page.sections) == 2
    end

    test "returns nested page by slug" do
      assert {:ok, page} = Filesystem.get_page("/blog/hello-world")
      assert page.title == "Hello World"
    end

    test "returns :error for unknown slug" do
      assert :error = Filesystem.get_page("/nonexistent")
    end
  end

  describe "get_page/2 with version option" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "returns published version by default" do
      assert {:ok, page} = Filesystem.get_page("/blog/morning-ritual")
      assert length(page.sections) == 2
      hero = hd(page.sections)
      assert hero.fields["heading"] == "The Morning Ritual"
    end

    test "returns specific version when version: option given" do
      assert {:ok, page} = Filesystem.get_page("/blog/morning-ritual", version: ~U[2024-11-15 14:00:00Z])
      assert length(page.sections) == 3
      hero = hd(page.sections)
      assert hero.fields["heading"] == "The Morning Ritual (Updated)"
    end

    test "returns :error for nonexistent version" do
      assert :error = Filesystem.get_page("/blog/morning-ritual", version: ~U[2099-01-01 00:00:00Z])
    end

    test "returns :error for nonexistent slug with version" do
      assert :error = Filesystem.get_page("/nonexistent", version: ~U[2024-01-01 00:00:00Z])
    end

    test "page has versions list" do
      assert {:ok, page} = Filesystem.get_page("/blog/morning-ritual")
      assert length(page.versions) == 2
    end

    test "page has published_version, updated_at" do
      assert {:ok, page} = Filesystem.get_page("/blog/morning-ritual")
      assert page.published_version == ~U[2024-09-01 06:00:00Z]
      assert page.updated_at == ~U[2024-11-15 14:00:00Z]
      assert page.published_at == ~U[2024-09-01 06:00:00Z]
    end

    test "version selection swaps sections and timestamps" do
      assert {:ok, page} = Filesystem.get_page("/blog/morning-ritual", version: ~U[2024-11-15 14:00:00Z])
      # Draft version has no published_at
      assert page.published_at == nil
      assert page.updated_at == ~U[2024-11-15 14:00:00Z]
    end

    test "shared section refs are resolved in all versions" do
      # Index page has only one version but all version sections should be resolved
      assert {:ok, page} = Filesystem.get_page("/")
      assert length(page.versions) == 1
      [version] = page.versions
      assert length(version.sections) == 2
    end
  end

  describe "list_pages/0" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns all pages" do
      pages = Filesystem.list_pages()
      assert length(pages) == 2
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert slugs == ["/", "/blog/hello-world"]
    end
  end

  describe "get_layout/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns layout by name" do
      assert {:ok, layout} = Filesystem.get_layout("default")
      assert %Layout{} = layout
      assert length(layout.header_sections) == 1
      assert hd(layout.header_sections).template == "nav"
    end

    test "returns :error for unknown layout" do
      assert :error = Filesystem.get_layout("nonexistent")
    end
  end

  describe "get_author/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns author by slug" do
      assert {:ok, author} = Filesystem.get_author("jeff")
      assert %Author{} = author
      assert author.name == "Jeff"
    end

    test "returns :error for unknown author" do
      assert :error = Filesystem.get_author("nobody")
    end
  end

  describe "list_authors/0" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns all authors" do
      authors = Filesystem.list_authors()
      assert length(authors) == 2
    end
  end

  describe "get_tag/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns tag by slug" do
      assert {:ok, tag} = Filesystem.get_tag("elixir")
      assert %Tag{} = tag
      assert tag.display_name == "Elixir"
    end

    test "returns :error for unknown tag" do
      assert :error = Filesystem.get_tag("nope")
    end
  end

  describe "list_tags/0" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns all tags" do
      tags = Filesystem.list_tags()
      assert length(tags) == 2
    end
  end

  describe "get_media/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns media by slug" do
      assert {:ok, media} = Filesystem.get_media("headshot")
      assert %Media{} = media
      assert media.alt == "Photo of Jeff"
    end

    test "returns :error for unknown media" do
      assert :error = Filesystem.get_media("nope")
    end
  end

  describe "list_media/0" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns all media" do
      media = Filesystem.list_media()
      assert length(media) == 1
    end
  end

  describe "get_section_template/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns section template by name" do
      assert {:ok, template} = Filesystem.get_section_template("hero")
      assert %SectionTemplate{} = template
      assert template.fields["heading"].required == true
    end

    test "returns :error for unknown template" do
      assert :error = Filesystem.get_section_template("nope")
    end
  end

  describe "list_section_templates/0" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns all section templates" do
      templates = Filesystem.list_section_templates()
      assert length(templates) == 4
    end
  end

  describe "list_pages/1 with filters" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "no filters returns all pages" do
      pages = Filesystem.list_pages()
      assert length(pages) == 6
    end

    test "filter by tag" do
      pages = Filesystem.list_pages(tag: "pastries")
      assert length(pages) == 1
      assert hd(pages).slug == "/menu"
    end

    test "filter by tag shared across pages" do
      pages = Filesystem.list_pages(tag: "coffee")
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert slugs == ["/", "/about", "/blog/morning-ritual", "/blog/upcoming-roast", "/careers", "/menu"]
    end

    test "filter by author" do
      pages = Filesystem.list_pages(author: "alex")
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert slugs == ["/about", "/careers", "/menu"]
    end

    test "filter by prefix" do
      pages = Filesystem.list_pages(prefix: "/blog/")
      assert length(pages) == 2
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert slugs == ["/blog/morning-ritual", "/blog/upcoming-roast"]
    end

    test "compose tag + author" do
      pages = Filesystem.list_pages(tag: "coffee", author: "alex")
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert slugs == ["/about", "/careers", "/menu"]
    end

    test "compose tag + prefix" do
      pages = Filesystem.list_pages(tag: "coffee", prefix: "/blog/")
      assert length(pages) == 2
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert slugs == ["/blog/morning-ritual", "/blog/upcoming-roast"]
    end

    test "no matches returns empty list" do
      assert Filesystem.list_pages(tag: "nonexistent") == []
    end

    test "prefix with no trailing slash still works" do
      pages = Filesystem.list_pages(prefix: "/blog")
      assert length(pages) == 2
    end

    test "raises on unknown filter key" do
      assert_raise ArgumentError, ~r/unknown filter :foo/, fn ->
        Filesystem.list_pages(foo: "bar")
      end
    end
  end

  describe "list_pages/1 with status filter" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "status: :published returns only published pages" do
      pages = Filesystem.list_pages(status: :published)
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      # Home, About, Menu, Morning Ritual are in the past. Upcoming Roast is 2099. Careers has no published_at.
      assert "/" in slugs
      assert "/about" in slugs
      assert "/menu" in slugs
      assert "/blog/morning-ritual" in slugs
      refute "/blog/upcoming-roast" in slugs
      refute "/careers" in slugs
    end

    test "status: :draft returns only draft/scheduled pages" do
      pages = Filesystem.list_pages(status: :draft)
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert "/blog/upcoming-roast" in slugs
      assert "/careers" in slugs
      refute "/" in slugs
    end

    test "status composes with other filters" do
      pages = Filesystem.list_pages(status: :published, prefix: "/blog/")
      assert length(pages) == 1
      assert hd(pages).slug == "/blog/morning-ritual"
    end
  end

  describe "find_redirect/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "finds redirect for old slug" do
      assert {:ok, "/about"} = Filesystem.find_redirect("/about-us")
      assert {:ok, "/about"} = Filesystem.find_redirect("/our-story")
    end

    test "finds redirect for blog slug history" do
      assert {:ok, "/blog/morning-ritual"} = Filesystem.find_redirect("/blog/first-cup")
    end

    test "returns :error for unknown slug" do
      assert :error = Filesystem.find_redirect("/nonexistent")
    end
  end

  describe "mixed sections" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "mixed .field.md content is merged into yml section" do
      assert {:ok, page} = Filesystem.get_page("/about")
      cta = Enum.find(page.sections, &(&1.template == "cta"))

      assert cta.fields["heading"] == "Come Visit Us"
      assert cta.fields["body"] =~ "seven days a week"
      assert cta.fields["body"] =~ "<strong>"
    end

    test "about page has all three sections" do
      assert {:ok, page} = Filesystem.get_page("/about")
      assert length(page.sections) == 3
      templates = Enum.map(page.sections, & &1.template)
      assert templates == ["hero", "richtext", "cta"]
    end
  end

  describe "shared sections" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "get_shared_section/1 returns by name" do
      assert {:ok, shared} = Filesystem.get_shared_section("main-nav")
      assert shared.name == "main-nav"
      assert shared.template == "nav"
      assert length(shared.fields["links"]) == 4
    end

    test "get_shared_section/1 returns :error for unknown" do
      assert :error = Filesystem.get_shared_section("nonexistent")
    end

    test "list_shared_sections/0 returns all" do
      shared = Filesystem.list_shared_sections()
      assert length(shared) == 2
      names = Enum.map(shared, & &1.name)
      assert "main-nav" in names
      assert "site-footer" in names
    end

    test "layout shared section refs are resolved" do
      {:ok, layout} = Filesystem.get_layout("default")
      header = hd(layout.header_sections)
      assert header.template == "nav"
      assert length(header.fields["links"]) == 4

      footer = hd(layout.footer_sections)
      assert footer.template == "footer"
      assert footer.fields["copyright"] == "2026 Ember & Bloom"
    end
  end

  describe "get_collection/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "returns collection by slug" do
      assert {:ok, collection} = Filesystem.get_collection("blog")
      assert collection.name == "Blog"
      assert collection.filters == %{prefix: "/blog/"}
    end

    test "returns :error for unknown slug" do
      assert :error = Filesystem.get_collection("nonexistent")
    end
  end

  describe "list_collections/0" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "returns all collections" do
      collections = Filesystem.list_collections()
      assert length(collections) == 5
      slugs = Enum.map(collections, & &1.slug)
      assert "blog" in slugs
      assert "coffee-reads" in slugs
      assert "coffee-by-maya" in slugs
      assert "multi-tag" in slugs
      assert "drafts" in slugs
    end
  end

  describe "list_collection_pages/1" do
    setup do
      start_supervised!({Filesystem, content_dir: @dummy})
      :ok
    end

    test "resolves pages for a prefix-filtered collection" do
      {:ok, collection} = Filesystem.get_collection("blog")
      pages = Filesystem.list_collection_pages(collection)
      assert length(pages) == 2
      slugs = Enum.map(pages, & &1.slug) |> Enum.sort()
      assert slugs == ["/blog/morning-ritual", "/blog/upcoming-roast"]
    end

    test "resolves pages for a tag-filtered collection" do
      {:ok, collection} = Filesystem.get_collection("coffee-reads")
      pages = Filesystem.list_collection_pages(collection)
      assert length(pages) == 6
    end

    test "sorts by collection sort_by and sort_direction" do
      {:ok, collection} = Filesystem.get_collection("coffee-reads")
      pages = Filesystem.list_collection_pages(collection)
      titles = Enum.map(pages, & &1.title)
      assert titles == Enum.sort(titles, :desc)
    end

    test "advanced filter_groups collection filters correctly" do
      {:ok, collection} = Filesystem.get_collection("coffee-by-maya")
      pages = Filesystem.list_collection_pages(collection)

      # Must have tag "coffee" AND author "maya"
      for page <- pages do
        assert "coffee" in page.tags
        assert "maya" in page.authors
      end
    end

    test "status draft collection returns only drafts" do
      {:ok, collection} = Filesystem.get_collection("drafts")
      pages = Filesystem.list_collection_pages(collection)

      for page <- pages do
        refute Brix.Page.published?(page)
      end
    end
  end

  describe "list_collections/0 with no collections" do
    setup do
      start_supervised!({Filesystem, content_dir: @valid})
      :ok
    end

    test "returns empty list" do
      assert Filesystem.list_collections() == []
    end
  end

  describe "start_link/1 with invalid content" do
    test "raises on validation errors" do
      assert_raise RuntimeError, ~r/validation failed/, fn ->
        start_supervised!({Filesystem, content_dir: @missing_site})
      end
    end
  end
end
