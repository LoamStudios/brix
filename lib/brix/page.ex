defmodule Brix.Page do
  @moduledoc """
  A content page. Has a slug, metadata, sections, and references
  to a layout, authors, and tags.
  """

  defstruct [:slug, :title, :meta_title, :meta_description,
             :og_title, :og_description, :og_image,
             :layout, :sections, :authors, :tags,
             :published_at, :slug_history, :extra]

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          title: String.t() | nil,
          meta_title: String.t() | nil,
          meta_description: String.t() | nil,
          og_title: String.t() | nil,
          og_description: String.t() | nil,
          og_image: String.t() | nil,
          layout: String.t() | nil,
          sections: [Brix.Section.t()] | nil,
          authors: [String.t()] | nil,
          tags: [String.t()] | nil,
          published_at: DateTime.t() | nil,
          slug_history: [String.t()] | nil,
          extra: map() | nil
        }

  @doc """
  Returns true if the page is published (published_at is set and not in the future).
  """
  def published?(%__MODULE__{published_at: nil}), do: false

  def published?(%__MODULE__{published_at: published_at}) do
    DateTime.compare(published_at, DateTime.utc_now()) != :gt
  end
end
