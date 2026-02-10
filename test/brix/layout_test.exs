defmodule Brix.LayoutTest do
  use ExUnit.Case, async: true

  alias Brix.{Layout, Section}

  test "creates with header and footer sections" do
    layout = %Layout{
      name: "default",
      header_sections: [
        %Section{template: "nav", position: 1, fields: %{"links" => []}}
      ],
      footer_sections: [
        %Section{template: "footer", position: 1, fields: %{"copyright" => "2026"}}
      ]
    }

    assert layout.name == "default"
    assert length(layout.header_sections) == 1
    assert hd(layout.header_sections).template == "nav"
    assert hd(layout.footer_sections).fields["copyright"] == "2026"
  end
end
