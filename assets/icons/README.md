# Google Sign-In Icon

## Required Icon

Please add a Google logo icon to this directory:
- **Filename:** `google.png`
- **Size:** 512x512 pixels (or higher resolution)
- **Format:** PNG with transparent background
- **Source:** Download from [Google Brand Resources](https://about.google/brand-resources/)
- **Path in code:** `icons/google.png` (Flutter automatically adds 'assets/' prefix)

## Current Status

⚠️ **Icon is missing** - The app will show a fallback icon (generic login icon) until you add the real Google logo.

## Alternative

If you don't have the Google icon yet:
1. The app will use a fallback icon (generic login icon) 
2. Download the official Google "G" logo from Google's brand guidelines
3. Save it as `assets/icons/google.png`

## Official Google Brand Guidelines

Google provides official brand assets:
- Visit: https://about.google/brand-resources/
- Download the "Google G Logo" 
- Use the standard colored version for light backgrounds
- Ensure you comply with Google's brand usage guidelines

## Icon Requirements

✅ Transparent background
✅ Standard Google colors (blue, red, yellow, green)
✅ Minimum 128x128px (recommend 512x512px)
✅ PNG format
✅ Named exactly: `google.png`
✅ Place in: `assets/icons/google.png`

## Web Configuration (For Web Platform)

If deploying to web, you'll also need to add Google Sign-In Client ID to `web/index.html`:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

Web Client ID from CREDENTIALS.md:
`284464943479-0al64mg2s50e6uisg3dapn1qfuf0639o.apps.googleusercontent.com`
