defmodule Brix.SectionTemplateTest do
  use ExUnit.Case, async: true

  alias Brix.SectionTemplate

  test "creates with name and field definitions" do
    template = %SectionTemplate{
      name: "hero",
      fields: %{
        "heading" => %{type: :string, required: true},
        "subheading" => %{type: :string, required: false},
        "image" => %{type: :media, required: false}
      }
    }

    assert template.name == "hero"
    assert template.fields["heading"].type == :string
    assert template.fields["heading"].required == true
    assert template.fields["image"].type == :media
  end

  test "supports list type with element type" do
    template = %SectionTemplate{
      name: "nav",
      fields: %{
        "links" => %{type: :list, of: :map, required: true}
      }
    }

    assert template.fields["links"].type == :list
    assert template.fields["links"].of == :map
  end
end
