# Web test on GitHub Pages

URL: **https://leonfighter1.github.io/suanming/**

The workflow `.github/workflows/pages.yml` builds the Flutter app for the web on every
push to `main` that touches `app/`, and publishes it to Pages. You can also run it by
hand from the Actions tab (**pages → Run workflow**).

## One-time setup (repository owner)

1. Settings → Pages → Build and deployment → Source: **GitHub Actions**.
2. Optional: Settings → Secrets and variables → Actions → **Variables** →
   `API_BASE_URL` = the public URL of a hosted API. Then re-run the workflow.

## Which API the page calls

The page is static. It calls the v1 API; it never holds the DeepSeek key.

| `API_BASE_URL` variable                   | Who can test                                                                    |
| ----------------------------------------- | ------------------------------------------------------------------------------- |
| not set (default `http://127.0.0.1:8787`) | Only someone running the API on the same computer as the browser: `npm run api` |
| a hosted API URL (https)                  | Anyone with the link                                                            |

Local API with the Pages page (Chrome or Edge):

```
npm run api        # allows http://localhost and https://leonfighter1.github.io
```

Then open the Pages URL and sign in with a dev account (`admin`/`admin`,
`xumei`/`xumei`, `test@mingli.local`/`Test-12345678`). The API also answers Chrome's
Private Network Access preflight, so the https page may call the local http API.
Safari blocks this mixed content; use a hosted API for Safari and phones.
To allow other origins: `MINGLI_CORS_ORIGINS=https://a.example,https://b.example npm run api`.

## Cache

Every page open loads the current build, in debug as well:

- `web/index.html` sends no-cache meta tags, unregisters any service worker, clears
  Cache Storage and loads `flutter_bootstrap.js` with a fresh query string.
- `web/flutter_bootstrap.js` loads `main.dart.js` with a fresh query string.
