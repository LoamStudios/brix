# Brix Usage Rules

Brix is a flat-file CMS library for Phoenix. It reads YAML and Markdown content from `priv/content/`, validates and caches it in ETS, and provides a structured API for rendering pages in LiveView.

## Core API

### Fetching Resources

All `get_*` functions return `{:ok, struct}` or `:error`. All `list_*` functions return a list.

```elixir
# Pages
{:ok, page} = Brix.get_page("/blog/hello")
pages = Brix.list_pages()

# Other resources
{:ok, layout} = Brix.get_layout("default")
{:ok, author} = Brix.get_author("maya")
{:ok, tag} = Brix.get_tag("coffee")
{:ok, media} = Brix.get_media("hero-image")
{:ok, section} = Brix.get_shared_section("main-nav")
{:ok, collection} = Brix.get_collection("blog")
{:ok, tmpl} = Brix.get_section_template("hero")
```

### Page Filters

`Brix.list_pages/1` accepts keyword opts. All filters compose.

```elixir
Brix.list_pages(
  tag: "coffee",            # pages with this tag slug
  author: "maya",           # pages with this author slug
  prefix: "/blog/",         # pages whose slug starts with prefix
  status: :published        # :published (default) | :draft | :all
)
```

### Page Helpers

```elixir
Brix.Page.published?(page)          # true if published_at <= now
Brix.Page.matches?(page, "query")   # case-insensitive search
Brix.Page.excerpt(page)             # plain-text excerpt, 200 chars
Brix.Page.excerpt(page, 100)        # custom length
```

### Collections

Collections define reusable page queries with filters and sort order.

```elixir
{:ok, collection} = Brix.get_collection("blog")
pages = Brix.list_collection_pages(collection)
```

### Slug Redirects

Pages can declare old slugs in `slug_history`. Look them up with:

```elixir
case Brix.find_redirect("/old-url") do
  {:ok, new_slug} -> push_navigate(socket, to: new_slug)
  :error -> raise NotFoundError
end
```

### Reloading Content

```elixir
Brix.reload()  # reloads all content from disk
```

The store is a GenServer (`Brix.Store.Filesystem`). After editing content files on disk, call `Brix.reload/0` to refresh the ETS cache.

## Section Fields Are String-Keyed

Section field maps use **string keys**, not atom keys. This is the most common mistake.

```elixir
# Correct
@fields["heading"]
@fields["body"]

# Wrong - will always be nil
@fields[:heading]
@fields.heading
```

## Richtext Fields Contain HTML

Richtext fields are converted from Markdown to HTML at load time. Use `raw/1` in templates.

```elixir
# Correct
{raw(@fields["body"])}

# Wrong - will render escaped HTML tags
{@fields["body"]}
```

## Use source_fields for Raw Markdown

Each `%Brix.Section{}` has both `fields` (HTML) and `source_fields` (raw Markdown). When you need the original Markdown (for LLM endpoints, feeds, etc.), use `source_fields`.

```elixir
# Correct - raw markdown preserved from load time
section.source_fields["body"]

# Wrong - regex-stripping HTML from the rendered output
section.fields["body"] |> String.replace(~r/<[^>]+>/, "")
```

## Rendering in LiveView

### Section Components

Define a module with function components. Each function name **must match** the section template name exactly.

```elixir
defmodule MyAppWeb.Sections do
  use Phoenix.Component

  # Template name "hero" -> function name hero/1
  def hero(assigns) do
    ~H"""
    <section>
      <h1>{@fields["heading"]}</h1>
    </section>
    """
  end

  # Template name "article_body" -> function name article_body/1
  def article_body(assigns) do
    ~H"""
    <article class="prose">
      {raw(@fields["body"])}
    </article>
    """
  end
end
```

### Dispatching Sections and Layouts

`Brix.Render.sections/1` dispatches each section to the matching function component. `Brix.Render.layout/1` renders header sections, inner block, then footer sections.

```heex
<Brix.Render.layout layout={@layout} module={MyAppWeb.Sections}>
  <Brix.Render.sections sections={@page.sections} module={MyAppWeb.Sections} />
</Brix.Render.layout>
```

### Media URLs

Resolve media slugs to serving paths with `Brix.Render.media_url/1`. Do not construct paths manually.

```elixir
# Correct
Brix.Render.media_url("hero-image")  #=> "/content/media/files/hero.jpg"

# Wrong
"/content/media/#{media.path}"
```

## SEO Metadata

Use `Brix.Meta.field/3` for SEO fields. It resolves with a page-then-site fallback chain. Do not access `page.meta_title` or `site.meta_title` directly.

```elixir
site = Brix.get_site()
{:ok, page} = Brix.get_page("/about")

Brix.Meta.field(page, site, :title)          # page.meta_title || page.title || site.meta_title || site.name
Brix.Meta.field(page, site, :description)    # page.meta_description || site.meta_description
Brix.Meta.field(page, site, :og_title)       # page.og_title || :title fallback
Brix.Meta.field(page, site, :og_description) # page.og_description || :description fallback
Brix.Meta.field(page, site, :og_image)       # page.og_image || site.og_image
```

Works with both `%Page{}` and `%Collection{}` structs.

## Store Setup

Add `Brix.Store.Filesystem` to your supervision tree:

```elixir
# application.ex
children = [
  {Brix.Store.Filesystem,
   content_dir: Path.join(:code.priv_dir(:my_app), "content")},
  # ...
]
```

Content is validated on boot. Validation errors block loading.

## Content Directory Structure

```
priv/content/
├── site.yml                          # Site config (required)
├── authors/{slug}.yml                # Author definitions
├── tags/{slug}.yml                   # Tag definitions
├── media/{slug}.yml                  # Media metadata
│   └── files/                        # Actual media files
├── templates/sections/{name}.yml     # Section field schemas
├── layouts/{name}.yml                # Header/footer section lists
├── shared_sections/{name}.yml        # Reusable section blocks
├── collections/{slug}.yml            # Page groupings with filters
└── pages/{slug}/
    ├── page.yml                      # Page metadata
    └── versions/{YYYYMMDDTHHMMSSz}/
        ├── version.yml               # published_at, updated_at
        └── sections/
            ├── 01-{name}.yml         # YAML section
            ├── 02-{name}.md          # Standalone markdown section
            └── 03-{name}.{field}.md  # Mixed: markdown field merged into YAML
```

### Section File Formats

**YAML** (`01-hero.yml`): Template and fields defined in YAML.

**Standalone Markdown** (`02-intro.md`): Template from frontmatter. Entire body becomes the content field.

**Mixed** (`03-cta.yml` + `03-cta.body.md`): YAML defines most fields. The `.body.md` file's content merges into the `body` field. The raw markdown is preserved in `source_fields`.

### Section Template Field Types

| Type       | Description                            |
| ---------- | -------------------------------------- |
| `string`   | Plain text                             |
| `richtext` | Markdown converted to HTML at load     |
| `media`    | Media slug reference                   |
| `url`      | URL string                             |
| `boolean`  | `true` / `false`                       |
| `integer`  | Numeric value                          |
| `list`     | List of items (optional `of:` subtype) |
| `map`      | Key-value object                       |

### Page Publishing

| `published_at` value | Status    |
| -------------------- | --------- |
| absent / `nil`       | Draft     |
| Future datetime      | Scheduled |
| Past datetime        | Published |

### Layouts

Layouts reference sections inline or via shared section refs. Shared refs are resolved at load time — the `%Layout{}` struct always contains fully resolved `%Section{}` structs.

```yaml
# layouts/default.yml
header_sections:
  - shared_section: main-nav      # resolved from shared_sections/main-nav.yml
footer_sections:
  - template: footer              # inline section definition
    fields:
      copyright: "2025 My Site"
```

## Common Mistakes

- **Atom keys on fields**: `@fields[:heading]` is always `nil`. Use `@fields["heading"]`.
- **Missing `raw/1`**: Richtext fields contain HTML. Without `raw/1`, tags render as escaped text.
- **Stripping HTML for markdown**: Use `source_fields`, not regex on `fields`.
- **Direct meta access**: Use `Brix.Meta.field/3` instead of `page.meta_title` to get the full fallback chain.
- **Wrong component name**: If the template is `"hero_home"`, the function must be `hero_home/1`, not `hero/1`.
- **Manual media paths**: Use `Brix.Render.media_url/1` to resolve slugs.
- **Forgetting reload**: After editing content files, call `Brix.reload/0` to refresh the cache.
