# TransitBar

TransitBar is a lightweight native macOS menu bar application for quickly checking upcoming transit departures from favorite stops. It is designed to feel like a system utility rather than a full transit app.


# UI Screenshots
<img width="429" height="497" alt="Screenshot 2026-06-05 at 6 43 55 PM" src="https://github.com/user-attachments/assets/fa33ad72-2838-4ebf-92a0-d80d5a56bcf0" />

## Release Process

GitHub Actions builds and tests TransitBar on every pull request using the `TransitBar.xcodeproj` project and `TransitBar` scheme.

To publish a release:

1. Create a version tag that starts with `v`, for example `v1.0.0`.
2. Push the tag to GitHub.
3. The release workflow builds the app with the `Release` configuration on the macOS runner, packages `TransitBar.app` into a DMG, and uploads the DMG to the GitHub Release for that tag.

Example:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Code signing and notarization are intentionally not configured yet, so release DMGs are unsigned development artifacts for now.
