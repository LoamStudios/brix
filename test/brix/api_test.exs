defmodule Brix.ApiTest do
  use ExUnit.Case

  @valid Path.expand("../fixtures/valid", __DIR__)

  setup do
    Application.put_env(:brix, :store, Brix.Store.Filesystem)
    start_supervised!({Brix.Store.Filesystem, content_dir: @valid})
    :ok
  end

  describe "Brix delegates to configured store" do
    test "get_site/0" do
      site = Brix.get_site()
      assert site.name == "Test Site"
    end

    test "get_page/1" do
      assert {:ok, page} = Brix.get_page("/")
      assert page.title == "Home"
    end

    test "list_pages/0" do
      pages = Brix.list_pages()
      assert length(pages) == 2
    end

    test "get_layout/1" do
      assert {:ok, layout} = Brix.get_layout("default")
      assert layout.name == "default"
    end

    test "get_author/1" do
      assert {:ok, author} = Brix.get_author("jeff")
      assert author.name == "Jeff"
    end

    test "list_authors/0" do
      assert length(Brix.list_authors()) == 2
    end

    test "get_tag/1" do
      assert {:ok, tag} = Brix.get_tag("elixir")
      assert tag.display_name == "Elixir"
    end

    test "list_tags/0" do
      assert length(Brix.list_tags()) == 2
    end

    test "get_media/1" do
      assert {:ok, media} = Brix.get_media("headshot")
      assert media.alt == "Photo of Jeff"
    end

    test "list_media/0" do
      assert length(Brix.list_media()) == 1
    end

    test "get_section_template/1" do
      assert {:ok, template} = Brix.get_section_template("hero")
      assert template.fields["heading"].required == true
    end

    test "list_section_templates/0" do
      assert length(Brix.list_section_templates()) == 4
    end
  end
end
