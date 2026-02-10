defmodule Brix.VersionTest do
  use ExUnit.Case, async: true

  alias Brix.Version

  describe "struct" do
    test "has default nil fields" do
      version = %Version{}
      assert version.version == nil
      assert version.published_at == nil
      assert version.updated_at == nil
      assert version.sections == nil
    end

    test "can be created with all fields" do
      now = DateTime.utc_now()
      sections = [%Brix.Section{template: "hero", position: 1, fields: %{}}]

      version = %Version{
        version: now,
        published_at: now,
        updated_at: now,
        sections: sections
      }

      assert version.version == now
      assert version.published_at == now
      assert version.updated_at == now
      assert version.sections == sections
    end
  end
end
