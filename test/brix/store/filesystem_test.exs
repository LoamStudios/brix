defmodule Brix.Store.FilesystemTest do
  use ExUnit.Case

  alias Brix.Store.Filesystem
  alias Brix.{Site, Page, Layout, Author, Tag, Media, SectionTemplate}

  @valid Path.expand("../../fixtures/valid", __DIR__)
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

  describe "start_link/1 with invalid content" do
    test "raises on validation errors" do
      assert_raise RuntimeError, ~r/validation failed/, fn ->
        start_supervised!({Filesystem, content_dir: @missing_site})
      end
    end
  end
end
