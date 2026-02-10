defmodule Brix.SiteTest do
  use ExUnit.Case, async: true

  alias Brix.Site

  test "creates with all fields" do
    site = %Site{
      name: "Jeff's Site",
      tagline: "Builder of things",
      meta_title: "Jeff | Builder",
      meta_description: "Personal site and blog",
      og_image: "headshot",
      favicon: "favicon",
      domain: "jeff.dev",
      extra: %{"analytics_id" => "UA-123"}
    }

    assert site.name == "Jeff's Site"
    assert site.domain == "jeff.dev"
    assert site.extra["analytics_id"] == "UA-123"
  end

  test "defaults to nil for all fields" do
    site = %Site{}

    assert site.name == nil
    assert site.extra == nil
  end
end
