# Brix

A structured content layer for Phoenix LiveView apps. Write content as YAML and Markdown files, Brix validates, loads, and serves it.

No GUI. No database (yet). Files are the authoring interface.

## Setup

```elixir
# mix.exs
{:brix, path: "../brix"}   # local during dev

# config/config.exs
config :brix, store: Brix.Store.Filesystem

# application.ex
children = [
  {Brix.Store.Filesystem, content_dir: Path.expand("priv/content")}
]
```

## Content directory

```
priv/content/
├── site.yml
├── authors/
│   └── maya.yml
├── tags/
│   └── coffee.yml
├── media/
│   ├── headshot.yml
│   └── files/
│       └── headshot.jpg
├── templates/
│   └── sections/
│       ├── hero.yml
│       └── richtext.yml
├── layouts/
│   └── default.yml
├── shared_sections/
│   ├── main-nav.yml
│   └── site-footer.yml
├── collections/
│   └── blog.yml
└── pages/
    ├── index/
    │   ├── page.yml
    │   └── versions/
    │       └── 20240315T090000Z/
    │           ├── version.yml
    │           └── sections/
    │               ├── 01-hero.yml
    │               ├── 02-gallery.yml
    │               ├── 02-gallery.slides/    # nested sections
    │               │   ├── 01-slide.yml
    │               │   └── 02-slide.yml
    │               └── 03-intro.md
    └── blog/
        └── morning-ritual/
            ├── page.yml
            └── versions/
                ├── 20240901T060000Z/
                │   ├── version.yml
                │   └── sections/
                │       ├── 01-hero.yml
                │       └── 02-body.md
                └── 20241115T140000Z/
                    ├── version.yml
                    └── sections/
                        ├── 01-hero.yml
                        ├── 02-body.md
                        └── 03-tips.yml
```

## File formats

### site.yml

```yaml
name: Ember & Bloom
tagline: Coffee worth slowing down for
meta_title: Ember & Bloom | Specialty Coffee
meta_description: A neighborhood coffee shop.
domain: emberandbloom.coffee
```

### authors/maya.yml

Slug is derived from the filename.

```yaml
name: Maya Chen
bio: Founder and head roaster.
avatar: headshot          # references media slug
url: https://example.com
```

### tags/coffee.yml

```yaml
display_name: Coffee
```

### media/headshot.yml

```yaml
alt: Photo of Maya
caption: At the roaster
content_type: image/jpeg
path: files/headshot.jpg   # relative to media/
```

### templates/sections/hero.yml

Defines the field contract for a section type. The validator checks content against these.

```yaml
fields:
  heading:
    type: string
    required: true
  subheading:
    type: string
  image:
    type: media
```

Supported field types: `string`, `richtext`, `media`, `url`, `integer`, `boolean`, `list`, `map`, `sections`.

### layouts/default.yml

Layouts define header and footer sections that wrap page content. Can reference shared sections or define sections inline.

```yaml
header_sections:
  - shared_section: main-nav
footer_sections:
  - shared_section: site-footer
```

Or inline:

```yaml
header_sections:
  - template: nav
    fields:
      links:
        - label: Home
          url: /
footer_sections:
  - template: footer
    fields:
      copyright: "2026"
```

### shared_sections/main-nav.yml

Reusable content blocks. Define once, reference from layouts or page sections by name.

```yaml
template: nav
fields:
  links:
    - label: Home
      url: /
    - label: About
      url: /about
```

### collections/blog.yml

Named page groupings with filters and sorting.

```yaml
name: Blog
filters:
  prefix: /blog/
sort_by: slug
sort_direction: asc
meta_title: Blog | Ember & Bloom
meta_description: Thoughts on coffee and craft.
```

Filter keys: `prefix`, `tag`, `author`. Sort fields: `slug`, `title`, `published_at`, `updated_at`.

### pages/index/page.yml

Page slug is derived from directory path (`pages/index/` → `/`, `pages/blog/hello/` → `/blog/hello`). Can be overridden with `slug:`.

```yaml
title: Home
layout: default
meta_title: Ember & Bloom | Home
meta_description: Specialty coffee in SE Portland.
authors: [maya]
tags: [coffee]
published_version: "20240315T090000Z"
slug_history:
  - /old-home-url
```

`published_version` points to the version directory name that serves as the live content. `slug_history` enables redirect lookups for old URLs.

### versions/20240315T090000Z/version.yml

Each version directory is named with a compact ISO timestamp (`YYYYMMDDTHHMMSSz`). The `version.yml` contains per-version metadata:

```yaml
published_at: "2024-03-15T09:00:00Z"
updated_at: "2024-03-15T09:00:00Z"
```

`published_at` controls draft/published status:
- Absent or `null` → draft
- Future datetime → scheduled (draft until that time)
- Past datetime → published

`updated_at` tracks when the version was last modified — useful for "Edited" dates in collection UIs.

**Page-level data** (shared across versions): slug, title, layout, authors, tags, meta_*, og_*, slug_history, extra, `published_version`.

**Version-level data** (per version): sections, `published_at`, `updated_at`.

The page struct's `sections` and `published_at` are populated from the published version for backward compatibility.

### Page sections

Sections live in `pages/*/versions/*/sections/`. Filename prefix sets order: `01-hero.yml` before `02-body.md`.

**YAML sections** — structured data:

```yaml
template: hero
fields:
  heading: Hello, I'm Maya
  subheading: I roast coffee
  image: headshot
```

**Markdown sections** — long-form content with frontmatter:

```markdown
---
template: richtext
---

This is the about section with **bold** and *italic*.
```

The markdown body becomes the `body` field, converted to HTML at load time.

**Mixed sections** — structured YAML fields plus a richtext markdown field:

A `.yml` file paired with a sibling `.field.md` file. The convention is `{position}-{name}.{fieldname}.md`:

```
sections/
├── 03-cta.yml          # structured fields
└── 03-cta.body.md      # richtext for the "body" field
```

`03-cta.yml`:
```yaml
template: cta
fields:
  heading: Come Visit Us
  subheading: We'd love to meet you.
```

`03-cta.body.md`:
```markdown
We're open **seven days a week** in SE Portland.
```

The loader merges them into a single Section struct with all fields combined. The markdown is converted to HTML. This avoids awkward inline richtext in YAML files.

**Shared section references** — reuse a shared section:

```yaml
shared_section: main-nav
```

**Nested sections** — sections that contain child sections:

Child sections live in subdirectories named `{NN}-{template}.{field}/` alongside their parent file. The directory name ties to the parent by matching the `{NN}-{template}` prefix, and the `.{field}` suffix names the field.

```
sections/
├── 02-gallery.yml
├── 02-gallery.slides/           # children for the "slides" field
│   ├── 01-slide.yml
│   ├── 01-slide.caption.md      # mixed markdown works in children too
│   └── 02-slide.yml
```

Declare nested fields in the section template with `type: sections`:

```yaml
# templates/sections/gallery.yml
fields:
  title:
    type: string
    required: true
  slides:
    type: sections
    of: slide           # constrains to "slide" template (single name or list)
    required: true
```

Render children in components using `Brix.Render.child_sections/1`:

```elixir
def gallery(assigns) do
  ~H"""
  <div class="gallery">
    <h2>{@fields["title"]}</h2>
    <Brix.Render.child_sections module={@module} children={@children} field="slides" />
  </div>
  """
end
```

The `@children` assign is a `%{field_name => [Section]}` map. `@module` is passed through so child rendering dispatches to the same component module. Nesting is recursive — children can have their own children.

## API

### Core

```elixir
# Site
Brix.get_site()
# => %Brix.Site{name: "Ember & Bloom", ...}

# Pages — returns published version's sections by default
Brix.get_page("/blog/morning-ritual")
# => {:ok, %Brix.Page{title: "The Morning Ritual", sections: [...], ...}}

# Request a specific version (e.g. preview a draft)
Brix.get_page("/blog/morning-ritual", version: ~U[2024-11-15 14:00:00Z])
# => {:ok, %Brix.Page{sections: [draft sections...], ...}}

# Access all versions
{:ok, page} = Brix.get_page("/blog/morning-ritual")
page.versions       # => [%Brix.Version{}, ...]
page.published_version  # => ~U[2024-09-01 06:00:00Z]
page.updated_at     # => ~U[2024-11-15 14:00:00Z]  (from latest version)

Brix.list_pages()
# => [%Brix.Page{}, ...]

# Filtered
Brix.list_pages(tag: "coffee")
Brix.list_pages(author: "maya")
Brix.list_pages(prefix: "/blog/")
Brix.list_pages(status: :published)
Brix.list_pages(status: :draft)
Brix.list_pages(tag: "coffee", prefix: "/blog/", status: :published)

# Layouts
Brix.get_layout("default")
# => {:ok, %Brix.Layout{header_sections: [...], footer_sections: [...]}}

# Authors, Tags, Media
Brix.get_author("maya")
Brix.list_authors()
Brix.get_tag("coffee")
Brix.list_tags()
Brix.get_media("headshot")
Brix.list_media()

# Section templates
Brix.get_section_template("hero")
Brix.list_section_templates()
```

### Collections

```elixir
Brix.list_collections()
# => [%Brix.Collection{slug: "blog", name: "Blog", ...}, ...]

{:ok, blog} = Brix.get_collection("blog")

blog
|> Brix.list_collection_pages()
|> Enum.map(& &1.title)
# => ["The Morning Ritual"]
```

### Shared sections

```elixir
Brix.list_shared_sections()
# => [%Brix.SharedSection{name: "main-nav", template: "nav", ...}, ...]

Brix.get_shared_section("main-nav")
# => {:ok, %Brix.SharedSection{...}}
```

### Drafts and publishing

```elixir
# Clock-aware: pages with published_at in the future are still drafts
Brix.list_pages(status: :published)    # published_at <= now
Brix.list_pages(status: :draft)        # published_at is nil or in the future

# Check a single page
{:ok, page} = Brix.get_page("/blog/upcoming")
Brix.Page.published?(page)
# => false (if published_at is in the future)
```

### Slug redirects

```elixir
# When a page has slug_history entries, old slugs resolve to the current one
Brix.find_redirect("/about-us")
# => {:ok, "/about"}

Brix.find_redirect("/nonexistent")
# => :error
```

### SEO metadata with fallbacks

```elixir
site = Brix.get_site()
{:ok, page} = Brix.get_page("/careers")

Brix.Meta.title(page, site)
# => page.meta_title || page.title || site.meta_title || site.name

Brix.Meta.description(page, site)
# => page.meta_description || site.meta_description

Brix.Meta.og_title(page, site)
# => page.og_title || Meta.title(page, site)

Brix.Meta.og_image(page, site)
# => page.og_image || site.og_image
```

## Rendering in LiveView

### 1. Define section components

One function per section template name. All fields arrive in `@fields` as a string-keyed map.

```elixir
defmodule MyAppWeb.Sections do
  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  def hero(assigns) do
    ~H"""
    <section class="hero">
      <h1>{@fields["heading"]}</h1>
      <p :if={@fields["subheading"]}>{@fields["subheading"]}</p>
      <img :if={@fields["image"]} src={Brix.Render.media_url(@fields["image"])} />
    </section>
    """
  end

  def richtext(assigns) do
    ~H"""
    <div class="prose">{raw(@fields["body"])}</div>
    """
  end

  def nav(assigns) do
    ~H"""
    <nav>
      <a :for={link <- @fields["links"]} href={link["url"]}>{link["label"]}</a>
    </nav>
    """
  end

  def footer(assigns) do
    ~H"""
    <footer>&copy; {@fields["copyright"]}</footer>
    """
  end
end
```

### 2. LiveView

```elixir
defmodule MyAppWeb.PageLive do
  use MyAppWeb, :live_view

  def handle_params(params, _uri, socket) do
    slug = case params do
      %{"slug" => parts} -> "/" <> Enum.join(parts, "/")
      _ -> "/"
    end

    case Brix.get_page(slug) do
      {:ok, page} ->
        {:ok, layout} = Brix.get_layout(page.layout)
        site = Brix.get_site()
        {:noreply, assign(socket, page: page, layout: layout, site: site)}

      :error ->
        # Check for slug redirect
        case Brix.find_redirect(slug) do
          {:ok, new_slug} -> {:noreply, redirect(socket, to: new_slug)}
          :error -> raise MyAppWeb.NotFoundError
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Brix.Render.layout layout={@layout} module={MyAppWeb.Sections}>
      <Brix.Render.sections sections={@page.sections} module={MyAppWeb.Sections} />
    </Brix.Render.layout>
    """
  end
end
```

### 3. SEO in root layout

```heex
<head>
  <title>{Brix.Meta.title(@page, @site)}</title>
  <meta name="description" content={Brix.Meta.description(@page, @site)} />
  <meta property="og:title" content={Brix.Meta.og_title(@page, @site)} />
  <meta property="og:description" content={Brix.Meta.og_description(@page, @site)} />
</head>
```

## Validation

Brix validates content on boot. Errors block loading. Warnings are logged.

Checked:
- Required fields present
- Field types match template schemas
- All references resolve (layouts, templates, authors, tags, media, shared sections)
- Media files exist on disk
- Unknown fields flagged with "did you mean?" suggestions

```elixir
result = Brix.Validator.validate("priv/content")
# => %{errors: [], warnings: []}
```

## Lifecycle

```
Author → Validate → Load → Serve
```

1. Write YAML/MD files in `priv/content/`
2. Boot validates all content against templates and cross-references
3. Valid content is parsed into structs, markdown converted to HTML, cached in ETS
4. LiveView calls `Brix.get_page(slug)`, renders via section components

Validation gates loading. Bad content never enters the store.
