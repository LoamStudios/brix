defmodule Brix.MetaTest do
  use ExUnit.Case, async: true

  alias Brix.{Collection, Meta, Page, Site}

  @site %Site{
    name: "Test Site",
    meta_title: "Test | Site",
    meta_description: "A test site",
    og_image: "default-og.jpg"
  }

  describe "field/3 :title with Page" do
    test "uses page meta_title when present" do
      page = %Page{meta_title: "About | Page", title: "About"}
      assert Meta.field(page, @site, :title) == "About | Page"
    end

    test "falls back to page title" do
      page = %Page{title: "About"}
      assert Meta.field(page, @site, :title) == "About"
    end

    test "falls back to site meta_title" do
      page = %Page{}
      assert Meta.field(page, @site, :title) == "Test | Site"
    end

    test "falls back to site name" do
      page = %Page{}
      site = %Site{name: "My Site"}
      assert Meta.field(page, site, :title) == "My Site"
    end
  end

  describe "field/3 :description with Page" do
    test "uses page meta_description when present" do
      page = %Page{meta_description: "Page desc"}
      assert Meta.field(page, @site, :description) == "Page desc"
    end

    test "falls back to site meta_description" do
      page = %Page{}
      assert Meta.field(page, @site, :description) == "A test site"
    end

    test "returns nil when neither set" do
      page = %Page{}
      site = %Site{}
      assert Meta.field(page, site, :description) == nil
    end
  end

  describe "field/3 :og_title with Page" do
    test "uses page og_title when present" do
      page = %Page{og_title: "OG Title", meta_title: "Meta Title"}
      assert Meta.field(page, @site, :og_title) == "OG Title"
    end

    test "falls back through title cascade" do
      page = %Page{meta_title: "Meta Title"}
      assert Meta.field(page, @site, :og_title) == "Meta Title"
    end
  end

  describe "field/3 :og_description with Page" do
    test "uses page og_description when present" do
      page = %Page{og_description: "OG Desc", meta_description: "Meta Desc"}
      assert Meta.field(page, @site, :og_description) == "OG Desc"
    end

    test "falls back through description cascade" do
      page = %Page{meta_description: "Meta Desc"}
      assert Meta.field(page, @site, :og_description) == "Meta Desc"
    end
  end

  describe "field/3 :og_image with Page" do
    test "uses page og_image when present" do
      page = %Page{og_image: "page-og.jpg"}
      assert Meta.field(page, @site, :og_image) == "page-og.jpg"
    end

    test "falls back to site og_image" do
      page = %Page{}
      assert Meta.field(page, @site, :og_image) == "default-og.jpg"
    end
  end

  # ── Collection fallback ──────────────────────────────────────────

  describe "field/3 :title with Collection" do
    test "uses collection meta_title when present" do
      collection = %Collection{meta_title: "Collection Meta", name: "My Collection"}
      assert Meta.field(collection, @site, :title) == "Collection Meta"
    end

    test "falls back to collection name" do
      collection = %Collection{name: "My Collection"}
      assert Meta.field(collection, @site, :title) == "My Collection"
    end

    test "falls back to site meta_title" do
      collection = %Collection{}
      assert Meta.field(collection, @site, :title) == "Test | Site"
    end

    test "falls back to site name" do
      collection = %Collection{}
      site = %Site{name: "My Site"}
      assert Meta.field(collection, site, :title) == "My Site"
    end
  end

  describe "field/3 :description with Collection" do
    test "uses collection meta_description when present" do
      collection = %Collection{meta_description: "Collection desc"}
      assert Meta.field(collection, @site, :description) == "Collection desc"
    end

    test "falls back to site meta_description" do
      collection = %Collection{}
      assert Meta.field(collection, @site, :description) == "A test site"
    end

    test "returns nil when neither set" do
      collection = %Collection{}
      site = %Site{}
      assert Meta.field(collection, site, :description) == nil
    end
  end

  describe "field/3 :og_title with Collection" do
    test "uses collection og_title when present" do
      collection = %Collection{og_title: "OG Title", meta_title: "Meta Title"}
      assert Meta.field(collection, @site, :og_title) == "OG Title"
    end

    test "falls back through title cascade" do
      collection = %Collection{meta_title: "Meta Title"}
      assert Meta.field(collection, @site, :og_title) == "Meta Title"
    end
  end

  describe "field/3 :og_description with Collection" do
    test "uses collection og_description when present" do
      collection = %Collection{og_description: "OG Desc", meta_description: "Meta Desc"}
      assert Meta.field(collection, @site, :og_description) == "OG Desc"
    end

    test "falls back through description cascade" do
      collection = %Collection{meta_description: "Meta Desc"}
      assert Meta.field(collection, @site, :og_description) == "Meta Desc"
    end
  end

  describe "field/3 :og_image with Collection" do
    test "uses collection og_image when present" do
      collection = %Collection{og_image: "collection-og.jpg"}
      assert Meta.field(collection, @site, :og_image) == "collection-og.jpg"
    end

    test "falls back to site og_image" do
      collection = %Collection{}
      assert Meta.field(collection, @site, :og_image) == "default-og.jpg"
    end
  end
end
