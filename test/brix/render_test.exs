defmodule Brix.RenderTest do
  use ExUnit.Case

  import Phoenix.LiveViewTest

  alias Brix.{Render, Section, Layout}

  @valid Path.expand("../fixtures/valid", __DIR__)

  # A test section component module
  defmodule TestSections do
    use Phoenix.Component
    import Phoenix.HTML, only: [raw: 1]

    def hero(assigns) do
      ~H"""
      <section><h1>{@fields["heading"]}</h1></section>
      """
    end

    def richtext(assigns) do
      ~H"""
      <div>{raw(@fields["body"])}</div>
      """
    end

    def nav(assigns) do
      ~H"""
      <nav>nav</nav>
      """
    end

    def footer(assigns) do
      ~H"""
      <footer>footer</footer>
      """
    end
  end

  setup do
    Application.put_env(:brix, :store, Brix.Store.Filesystem)
    start_supervised!({Brix.Store.Filesystem, content_dir: @valid})
    :ok
  end

  describe "sections/1" do
    test "renders sections by dispatching to component module" do
      sections = [
        %Section{template: "hero", position: 1, fields: %{"heading" => "Hello"}},
        %Section{template: "richtext", position: 2, fields: %{"body" => "<p>World</p>"}}
      ]

      html = render_component(&Render.sections/1,
        sections: sections,
        module: TestSections
      )

      assert html =~ "<h1>Hello</h1>"
      assert html =~ "<p>World</p>"
    end
  end

  describe "layout/1" do
    test "renders header, slot, and footer" do
      layout = %Layout{
        name: "default",
        header_sections: [%Section{template: "nav", position: 1, fields: %{}}],
        footer_sections: [%Section{template: "footer", position: 1, fields: %{}}]
      }

      html = render_component(&Render.layout/1,
        layout: layout,
        module: TestSections,
        inner_block: [%{__slot__: :inner_block, inner_block: fn _args, _caller -> "page content" end}]
      )

      assert html =~ "nav"
      assert html =~ "footer"
    end
  end

  describe "media_url/1" do
    test "resolves media slug to path" do
      assert Render.media_url("headshot") == "/content/media/files/headshot.jpg"
    end

    test "returns empty string for unknown slug" do
      assert Render.media_url("nonexistent") == ""
    end
  end
end
