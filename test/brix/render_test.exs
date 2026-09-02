defmodule Brix.RenderTest do
  use ExUnit.Case

  import Phoenix.LiveViewTest

  alias Brix.{Layout, Render, Section}

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

    def gallery(assigns) do
      ~H"""
      <div class="gallery">
        <h2>{@fields["title"]}</h2>
        <Brix.Render.child_sections module={@module} children={@children} field="slides" />
      </div>
      """
    end

    def slide(assigns) do
      ~H"""
      <div class="slide"><h3>{@fields["heading"]}</h3></div>
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

      html =
        render_component(&Render.sections/1,
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

      html =
        render_component(&Render.layout/1,
          layout: layout,
          module: TestSections,
          inner_block: [
            %{__slot__: :inner_block, inner_block: fn _args, _caller -> "page content" end}
          ]
        )

      assert html =~ "nav"
      assert html =~ "footer"
    end
  end

  describe "child_sections/1" do
    test "renders children for a specific field" do
      slides = [
        %Section{template: "slide", position: 1, fields: %{"heading" => "Slide 1"}},
        %Section{template: "slide", position: 2, fields: %{"heading" => "Slide 2"}}
      ]

      gallery = %Section{
        template: "gallery",
        position: 1,
        fields: %{"title" => "My Gallery"},
        children: %{"slides" => slides}
      }

      html =
        render_component(&Render.sections/1,
          sections: [gallery],
          module: TestSections
        )

      assert html =~ "My Gallery"
      assert html =~ "Slide 1"
      assert html =~ "Slide 2"
    end

    test "renders nothing for empty field" do
      gallery = %Section{
        template: "gallery",
        position: 1,
        fields: %{"title" => "Empty Gallery"},
        children: %{}
      }

      html =
        render_component(&Render.sections/1,
          sections: [gallery],
          module: TestSections
        )

      assert html =~ "Empty Gallery"
      refute html =~ "Slide"
    end

    test "render_section passes children and module in assigns" do
      section = %Section{
        template: "gallery",
        position: 1,
        fields: %{"title" => "Test"},
        children: %{
          "slides" => [
            %Section{template: "slide", position: 1, fields: %{"heading" => "S1"}}
          ]
        }
      }

      # Render through the sections component to get full HTML
      html =
        render_component(&Render.sections/1,
          sections: [section],
          module: TestSections
        )

      assert html =~ "Test"
      assert html =~ "S1"
    end

    test "existing components still work without using children" do
      sections = [
        %Section{template: "hero", position: 1, fields: %{"heading" => "Works"}}
      ]

      html =
        render_component(&Render.sections/1,
          sections: sections,
          module: TestSections
        )

      assert html =~ "Works"
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
