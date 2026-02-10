defmodule Brix.SharedSectionTest do
  use ExUnit.Case, async: true

  alias Brix.SharedSection

  test "creates with all fields" do
    shared = %SharedSection{
      name: "main-nav",
      template: "nav",
      fields: %{"links" => [%{"label" => "Home", "url" => "/"}]}
    }

    assert shared.name == "main-nav"
    assert shared.template == "nav"
    assert length(shared.fields["links"]) == 1
  end
end
