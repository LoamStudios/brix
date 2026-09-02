# AGENTS.md

Project conventions and context for AI agents and contributors working in Brix.

## What This Is

Brix is a structured content layer for Phoenix LiveView applications. Content is
authored as YAML and Markdown files on disk; Brix validates it, loads it into
structs, and renders it. There is no GUI and no database. Files are the
authoring interface.

## Project Structure

```
lib/brix/
  reader.ex            # Reads the content tree from disk into structs
  store.ex             # Store behaviour
  store/filesystem.ex  # Filesystem store (GenServer, loads content at boot)
  validator.ex         # Validates the content tree against section templates
  validator/issue.ex   # A single validation issue
  render.ex            # Renders sections and Markdown into LiveView
  gen.ex               # Shared logic behind the generator mix tasks

  site.ex              # Site-wide settings
  page.ex              # A page and its versions
  version.ex           # A dated version of a page
  section.ex           # A section within a version, may nest children
  section_template.ex  # Declares the fields a section accepts
  shared_section.ex    # A section reused across pages
  layout.ex            # Page layout
  collection.ex        # A queryable set of pages
  collection/filter_group.ex   # Filter groups and conditions
  collection/filter_engine.ex  # Evaluates filters against pages
  author.ex, tag.ex, media.ex, meta.ex

lib/mix/tasks/         # brix.gen.page, brix.gen.section, brix.gen.version,
                       # brix.list, brix.validate
test/                  # Mirrors the lib/ structure
cheatsheets/           # Shipped with the docs
```

## Content Directory

Content lives under a `content_dir` given to `Brix.Store.Filesystem` at boot.
The tree holds `site.yml`, plus `authors/`, `tags/`, `media/`, `templates/`,
`layouts/`, `shared_sections/`, `collections/`, and `pages/`. A page directory
holds `page.yml` and a `versions/` directory keyed by UTC timestamp. Sections
are timestamp-ordered files inside a version, and a `NN-name.slides/` directory
alongside a section nests children under it.

## Running Checks

- `mise precommit` — format check, compile with warnings as errors, credo strict, then tests
- `mise check` — the checks without the tests
- `mise fix` — format and auto-fix changed files
- `mise test` — tests only

## Key Conventions

- Tests mirror the `lib/` directory structure
- A section may carry both YAML fields and Markdown bodies; a `NN-name.field.md`
  file supplies the named field for the section with the matching prefix
- `source_fields` holds the raw Markdown behind a rendered field
- Validation is a separate pass over a loaded tree, never part of reading
- Avoid abbreviations in public API names

## Known Debt

Credo strict currently reports findings in this repo, mostly nesting depth and
function complexity in the reader and validator. They predate the linter being
added and are not a regression.
