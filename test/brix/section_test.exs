defmodule Brix.SectionTest do
  use ExUnit.Case, async: true

  alias Brix.Section

  test "creates with template, position, and fields" do
    section = %Section{
      template: "hero",
      position: 1,
      fields: %{"heading" => "Welcome", "image" => "headshot"}
    }

    assert section.template == "hero"
    assert section.position == 1
    assert section.fields["heading"] == "Welcome"
  end

  test "fields is an open map — any keys allowed" do
    section = %Section{
      template: "custom",
      position: 1,
      fields: %{"anything" => "goes", "nested" => %{"deep" => true}}
    }

    assert section.fields["nested"]["deep"] == true
  end
end
