defmodule Brix do
  @moduledoc """
  Structured content layer for Phoenix apps.

  Delegates to the configured store backend. Configure in your app:

      config :brix, store: Brix.Store.Filesystem, content_dir: "priv/content"
  """
end
