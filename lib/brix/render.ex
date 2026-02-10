defmodule Brix.Render do
  @moduledoc """
  Render helpers for Phoenix LiveView. Dispatches sections to
  your app's function components by template name.
  """

  use Phoenix.Component

  @doc """
  Renders a list of sections by dispatching each to the corresponding
  function component in `module`. The component function name matches
  the section's template name.
  """
  attr :sections, :list, required: true
  attr :module, :atom, required: true

  def sections(assigns) do
    ~H"""
    <%= for section <- @sections do %>
      {render_section(@module, section)}
    <% end %>
    """
  end

  @doc """
  Renders a layout by dispatching its header sections, yielding the inner block,
  then dispatching its footer sections.
  """
  attr :layout, :map, required: true
  attr :module, :atom, required: true
  slot :inner_block, required: true

  def layout(assigns) do
    ~H"""
    <%= for section <- @layout.header_sections do %>
      {render_section(@module, section)}
    <% end %>
    {render_slot(@inner_block)}
    <%= for section <- @layout.footer_sections do %>
      {render_section(@module, section)}
    <% end %>
    """
  end

  @doc """
  Renders a single section by dispatching to the matching function component
  in `module`. Passes `@fields`, `@children`, and `@module` as assigns.
  """
  def render_section(module, section) do
    Code.ensure_loaded!(module)
    func = String.to_atom(section.template)

    unless function_exported?(module, func, 1) do
      raise ArgumentError,
            "no section renderer #{module}.#{func}/1 for template #{inspect(section.template)}"
    end

    assigns = %{fields: section.fields, children: section.children, module: module, __changed__: %{}}
    apply(module, func, [assigns])
  end

  @doc """
  Renders child sections for a specific field. Use inside section components
  to render nested sections.

  ## Example

      def gallery(assigns) do
        ~H\"""
        <div class="gallery">
          <h2>{@fields["title"]}</h2>
          <Brix.Render.child_sections module={@module} children={@children} field="slides" />
        </div>
        \"""
      end
  """
  attr :module, :atom, required: true
  attr :children, :map, required: true
  attr :field, :string, required: true

  def child_sections(assigns) do
    ~H"""
    <%= for section <- Map.get(@children, @field, []) do %>
      {render_section(@module, section)}
    <% end %>
    """
  end

  @doc """
  Resolves a media slug to its serving path.
  """
  @spec media_url(String.t()) :: String.t()
  def media_url(slug) do
    case Brix.get_media(slug) do
      {:ok, media} -> "/content/media/" <> media.path
      :error -> ""
    end
  end
end
