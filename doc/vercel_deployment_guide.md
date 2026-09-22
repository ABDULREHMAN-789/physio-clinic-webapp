# Vercel Deployment & SPA Routing Guide

## 1. Problem Diagnosis: Why Did Vercel Return "404 NOT_FOUND"?

The "404 NOT_FOUND" error on Vercel typically occurs due to two root causes in Flutter web deployments:

1. **Missing or Mismatched Output Directory (`build/web` vs `public/`)**:
   - Flutter compiles web production bundles into `build/web/`.
   - However, this repository contains a `public/` folder (used for font assets). By default, Vercel detects any folder named `public` and treats it as the static website root.
   - Because `public/` did not contain an `index.html`, Vercel attempted to serve files from `public/`, resulting in an immediate **`404: NOT_FOUND`**.

2. **Single Page Application (SPA) Deep-Linking with GoRouter**:
   - GoRouter manages navigation client-side via browser URLs (e.g. `/dashboard`, `/patients`, `/sessions`, `/billing`).
   - When a user refreshes the page or navigates directly to a sub-route, the browser requests `/dashboard` directly from the Vercel server.
   - Without an SPA rewrite rule (`rewrites` in `vercel.json`), Vercel looks for a physical file named `dashboard.html` or `dashboard/index.html` on the server and returns 404.

---

## 2. Configuration Files Created

### 2.1 `vercel.json` (Root Directory)
Ensures Vercel serves `build/web` and rewrites all incoming routes to `/index.html` for GoRouter:

```json
{
  "outputDirectory": "build/web",
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```

### 2.2 `build.sh` (Root Directory)
An automated build script that handles Flutter SDK cloning, web enablement, dependency fetching, and production compilation:

```bash
#!/bin/bash
set -e

# 1. Install or locate Flutter SDK
if command -v flutter &> /dev/null; then
  echo ">>> Flutter is already in PATH."
else
  if [ ! -d "flutter" ]; then
    echo ">>> Cloning Flutter SDK (stable branch)..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
  fi
  export PATH="$PATH:$(pwd)/flutter/bin"
fi

# 2. Build Flutter Web release
flutter config --enable-web
flutter pub get
flutter build web --release --base-href /
```

---

## 3. Vercel Project Dashboard Settings (Step-by-Step)

To configure your Vercel project, follow these steps in your Vercel Dashboard:

1. Go to **[vercel.com](https://vercel.com)** and open your project: **`physio-clinic-webapp`**.
2. Navigate to **Settings** > **General**.
3. Scroll down to the **Build & Development Settings** section.
4. Toggle **Override** for the following fields and set their exact values:

| Setting | Value | Description |
| :--- | :--- | :--- |
| **Framework Preset** | `Other` | Tells Vercel not to use Next.js/React defaults. |
| **Build Command** | `bash build.sh` | Executes the automated Flutter build script. |
| **Output Directory** | `build/web` | Location where Flutter outputs the compiled HTML/JS/Wasm files. |
| **Install Command** | `if [ ! -d "flutter" ]; then git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter; fi` | *(Optional if using `bash build.sh` which automatically clones Flutter if missing).* |

5. Click **Save**.

---

## 4. Redeploying Your Application

Once the settings are saved:
1. Go to the **Deployments** tab in your Vercel dashboard.
2. Click the three dots (`...`) on the latest deployment and select **Redeploy**.
3. (Or push a new commit to your `main` branch to trigger an automatic build).

---

## 5. Post-Deployment Verification Checklist

Once the deployment completes with status **Ready**:
- [ ] Visit the root URL: `https://<your-project>.vercel.app/`
- [ ] Verify that the application redirects smoothly to `/splash` then `/dashboard` (or `/login`).
- [ ] Test GoRouter deep linking by navigating to `https://<your-project>.vercel.app/patients` and hard refreshing (`Ctrl + F5` or `Cmd + Shift + R`).
- [ ] Verify no 404 error is shown and the page loads seamlessly.
