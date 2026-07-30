# Store assets

**1320 x 2868** — Apple's 6.9" iPhone slot. Apple scales this size down for
every smaller iPhone, so one set covers the whole iPhone range.

- `ar-6.9/` — Arabic. **This is the set to upload.**
- `en-6.9/` — English chrome, but the milestone/week content in the shots is
  Arabic, because the content itself is Arabic-only. See
  `docs/APP_STORE_LISTING.md` before publishing an English localization.

Upload in filename order; the numeric prefix is the display order.

Regenerate: run the `Screenshots` workflow (it uses `-seed_demo 1` for sample
posts, no ads, no ATT prompt), download the artifact, then

    python tools/store_screenshots.py <artifact_dir> store-assets/ar-6.9 --lang ar
