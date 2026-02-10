defmodule Brix.MediaTest do
  use ExUnit.Case, async: true

  alias Brix.Media

  test "creates with all fields" do
    media = %Media{
      slug: "headshot",
      path: "files/headshot.jpg",
      alt: "Photo of Jeff",
      caption: "At the beach",
      content_type: "image/jpeg",
      extra: %{}
    }

    assert media.slug == "headshot"
    assert media.path == "files/headshot.jpg"
    assert media.alt == "Photo of Jeff"
    assert media.content_type == "image/jpeg"
  end
end
