# Firebase Hosting — privacy policy page

Serves `docs/privacy/index.html` at
`https://baby-ar-ios.web.app/` for the App Store listing's
**Privacy Policy URL** field.

## Why a separate site, not pt-ar-ios

`pt-ar-ios.web.app` already serves the pregnancy app's privacy policy and terms,
and that URL is referenced by the Pregnancy Guide's live App Store listing.
Deploying this app's page over that site would replace those files and break a
shipped listing. A second site in the same Firebase project keeps them apart.

## One-time: create the site

```bash
firebase hosting:sites:create baby-ar-ios --project pregnancy-tracker-57bf7
```

## Deploy

From this directory:

```bash
firebase deploy --only hosting:baby-privacy --project pregnancy-tracker-57bf7
```

Then verify `https://baby-ar-ios.web.app/` loads before pasting it into
App Store Connect. Apple rejects submissions whose privacy policy URL 404s.
