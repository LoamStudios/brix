defmodule Brix.Render do
  @moduledoc """
  Render helpers for Phoenix LiveView. Dispatches sections to
  your app's function components by template name.
  """

  use Phoenix.Component

  attr :sections, :list, required: true
  attr :module, :atom, required: true

  def sections(assigns) do
    ~H"""
    <%= for section <- @sections do %>
      {render_section(@module, section)}
    <% end %>
    """
  end

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

  defp render_section(module, section) do
    func = String.to_existing_atom(section.template)
    assigns = %{fields: section.fields, __changed__: %{}}
    apply(module, func, [assigns])
  end

  @doc """
  Resolves a media slug to its serving path.
  """
  def media_url(slug) do
    case Brix.get_media(slug) do
      {:ok, media} -> "/content/media/" <> media.path
      :error -> ""
    end
  end
end
