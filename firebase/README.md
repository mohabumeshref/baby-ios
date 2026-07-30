# Firebase Hosting — privacy policy page

Serves `docs/site/` at
`https://baby-ar-ios.web.app` for the App Store listing.s
**Privacy Policy URL** field.

## Why a separate site, not pt-ar-ios

`pt-ar-ios.web.app` already serves the pregnancy app's privacy policy and terms,
and that URL is referenced by the Pregnancy Guide's live App Store listing.
Deploying this app's page over that site would replace those files and break a
shipped listing. A second site in the same Firebase project keeps them apart.

`firebase.json` and `.firebaserc` live at the **repo root**, not here: Hosting
refuses a `public` directory outside the config's own directory, so `docs/site`
has to be reachable without `../`.

## One-time: create the site

Already done - `baby-ar-ios` exists in `pregnancy-tracker-57bf7`. For reference:

```bash
firebase hosting:sites:create baby-ar-ios --project pregnancy-tracker-57bf7
```

## Deploy

From the **repo root**:

```bash
firebase deploy --only hosting:baby-privacy --project pregnancy-tracker-57bf7
```

Pages:

| URL | Purpose |
|---|---|
| `https://baby-ar-ios.web.app/` | landing |
| `https://baby-ar-ios.web.app/privacy` | App Store **Privacy Policy URL** |
| `https://baby-ar-ios.web.app/support` | App Store **Support URL** |

Verify all three load before pasting them into App Store Connect - Apple rejects
submissions whose privacy policy URL 404s.
