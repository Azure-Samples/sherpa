---
name: page-banners
description: "Add styled banners to MkDocs documentation pages. Use when: adding a banner to a new camp page, adding a banner to a non-camp page like prerequisites or contributing, styling doc page headers with the deep teal gradient, creating consistent page headers across the workshop site."
argument-hint: "Specify the doc file to add a banner to, e.g., 'docs/camps/camp3-io-security/index.md'"
---

# Page Banners

Add a consistent deep teal gradient banner to MkDocs documentation pages. The banner supports two visual modes: a **custom image** (for camp landing pages) or a **Material Icon** (for utility pages like Prerequisites or Contributing).

## When to Use

- Adding a new camp landing page that needs a banner
- Adding a banner to a non-camp page (prerequisites, contributing, etc.)
- Ensuring visual consistency across the workshop site

## Prerequisites

The following must already be in place (they are set up in this repo):

1. **Google Material Icons font** loaded in `docs/overrides/main.html`:
   ```html
   <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet" />
   ```

2. **Banner CSS classes** defined in `docs/stylesheets/extra.css` under the `/* ── Camp Page Banners ── */` section.

## Banner Templates

### With Custom Image

Use this for camp landing pages where a small illustration exists in `docs/images/`.

```html
<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">LABEL TEXT</div>
      <h1>Page Title</h1>
      <p>One or two sentence description of the page content.</p>
    </div>
    <div class="camp-banner-image">
      <img src="PATH_TO_IMAGE" alt="Alt text" />
    </div>
  </div>
</div>
```

### With Material Icon

Use this for utility or reference pages that don't have a custom illustration.

```html
<div class="camp-banner">
  <div class="camp-banner-content">
    <div class="camp-banner-text">
      <div class="camp-banner-label">LABEL TEXT</div>
      <h1>Page Title</h1>
      <p>One or two sentence description of the page content.</p>
    </div>
    <div class="camp-banner-image">
      <span class="banner-icon"><span class="material-icons">ICON_NAME</span></span>
    </div>
  </div>
</div>
```

Browse icons at [fonts.google.com/icons](https://fonts.google.com/icons?icon.set=Material+Icons).

## Procedure

### Step 1: Determine Banner Type

- **Camp landing page with image** → use the image template
- **Utility/reference page without image** → use the Material Icon template

### Step 2: Choose Label and Content

| Element | Guidelines | Examples |
|---------|-----------|----------|
| **Label** | Short uppercase badge, 1–2 words | `Camp 1`, `Base Camp`, `Before You Climb`, `Community` |
| **Title** | The page heading, concise | `Identity & Access Management`, `Prerequisites` |
| **Description** | One sentence summarizing the page | `Defend against injection attacks and data leakage...` |

### Step 3: Determine Image Path

Image paths in banner HTML are **not rewritten by MkDocs** (they're raw HTML, not Markdown). The path must be relative from the page's **served URL**, not the source file location.

| Source file location | Served URL | Path to `docs/images/` |
|---------------------|------------|----------------------|
| `docs/camps/base-camp.md` | `/camps/base-camp/` | `../../images/filename.png` |
| `docs/camps/camp1-identity.md` | `/camps/camp1-identity/` | `../../images/filename.png` |
| `docs/camps/camp2-gateway/index.md` | `/camps/camp2-gateway/` | `../../images/filename.png` |
| `docs/prerequisites.md` | `/prerequisites/` | `../images/filename.png` |
| `docs/resources/contributing.md` | `/resources/contributing/` | `../../images/filename.png` |

**Rule of thumb:** Count the path segments in the served URL (excluding the trailing slash) and go up that many levels. For example, `/camps/base-camp/` is 2 segments → `../../images/`.

### Step 4: Replace Existing Header

Remove the old header elements (typically `# Title`, subtitle, and hero image) and replace with the banner HTML. The banner replaces all of:

```markdown
# Page Title              ← remove
*Subtitle text*           ← remove
![Image](path/image.png)  ← remove
```

### Step 5: Update Frontmatter

Add `toc` to the `hide` list if it's a landing-style page:

```yaml
---
hide:
  - toc
---
```

### Step 6: Verify

Run `mkdocs serve` and check:

- Banner renders with the deep teal gradient
- Image or icon appears on the right side
- Text is left-aligned and readable
- Responsive: on narrow viewports, the image/icon stacks above the text

## Existing Banners

| Page | Label | Type | Image/Icon |
|------|-------|------|-----------|
| Landing (`docs/index.md`) | `AZURE-SAMPLES / SHERPA` | Hero banner (different class: `.hero-banner`) | `sherpa-mcp-workshop-sm.png` |
| Base Camp | `Base Camp` | Image | `sherpa-base-camp-sm.png` |
| Camp 1 | `Camp 1` | Image | `sherpa-identity-sm.png` |
| Camp 2 | `Camp 2` | Image | `sherpa-gateway-sm.png` |
| Camp 3 | `Camp 3` | Image | `sherpa-security-sm.png` |
| Camp 4 | `Camp 4` | Image | `sherpa-monitoring-sm.png` |
| Prerequisites | `Before You Climb` | Icon | `checklist` |
| Contributing | `Community` | Icon | `group_add` |

## Image Guidelines

For camp images used in banners:

| Property | Recommendation |
|----------|---------------|
| **Source size** | 600 × 600px (square works best) |
| **Format** | PNG (if transparency needed), otherwise WebP/JPEG |
| **File size** | < 100KB |
| **Naming** | `sherpa-{topic}-sm.png` |
| **Location** | `docs/images/` |

The CSS constrains images to `max-width: 220px` and adds a border radius + shadow automatically.

## Notes

- The landing page (`docs/index.md`) uses a **different, larger** banner class (`.hero-banner`) with CTA buttons. Do not use `.camp-banner` for the landing page.
- The `banner-icon` class renders a frosted circle (`140px`) with the icon centered inside. It pairs with the same `.camp-banner-image` wrapper.
- All banner styles are responsive — on screens < 768px, the layout stacks vertically with the image/icon above the text.
