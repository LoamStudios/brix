defmodule Brix.MetaTest do
  use ExUnit.Case, async: true

  alias Brix.{Meta, Page, Site}

  @site %Site{
    name: "Test Site",
    meta_title: "Test | Site",
    meta_description: "A test site",
    og_image: "default-og.jpg"
  }

  describe "title/2" do
    test "uses page meta_title when present" do
      page = %Page{meta_title: "About | Page", title: "About"}
      assert Meta.title(page, @site) == "About | Page"
    end

    test "falls back to page title" do
      page = %Page{title: "About"}
      assert Meta.title(page, @site) == "About"
    end

    test "falls back to site meta_title" do
      page = %Page{}
      assert Meta.title(page, @site) == "Test | Site"
    end

    test "falls back to site name" do
      page = %Page{}
      site = %Site{name: "My Site"}
      assert Meta.title(page, site) == "My Site"
    end
  end

  describe "description/2" do
    test "uses page meta_description when present" do
      page = %Page{meta_description: "Page desc"}
      assert Meta.description(page, @site) == "Page desc"
    end

    test "falls back to site meta_description" do
      page = %Page{}
      assert Meta.description(page, @site) == "A test site"
    end

    test "returns nil when neither set" do
      page = %Page{}
      site = %Site{}
      assert Meta.description(page, site) == nil
    end
  end

  describe "og_title/2" do
    test "uses page og_title when present" do
      page = %Page{og_title: "OG Title", meta_title: "Meta Title"}
      assert Meta.og_title(page, @site) == "OG Title"
    end

    test "falls back through title cascade" do
      page = %Page{meta_title: "Meta Title"}
      assert Meta.og_title(page, @site) == "Meta Title"
    end
  end

  describe "og_description/2" do
    test "uses page og_description when present" do
      page = %Page{og_description: "OG Desc", meta_description: "Meta Desc"}
      assert Meta.og_description(page, @site) == "OG Desc"
    end

    test "falls back through description cascade" do
      page = %Page{meta_description: "Meta Desc"}
      assert Meta.og_description(page, @site) == "Meta Desc"
    end
  end

  describe "og_image/2" do
    test "uses page og_image when present" do
      page = %Page{og_image: "page-og.jpg"}
      assert Meta.og_image(page, @site) == "page-og.jpg"
    end

    test "falls back to site og_image" do
      page = %Page{}
      assert Meta.og_image(page, @site) == "default-og.jpg"
    end
  end
end
