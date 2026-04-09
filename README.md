# LoopholeUI

LoopholeUI is a native macOS app for Brendan Hogan's [Loophole framework](https://github.com/brendanhogan/loophole), redesigned for non-technical users.

It keeps the full workflow inside a clean Mac-style interface:

- moral principles
- Legislator
- Loophole Finder
- Overreach Finder
- Judge
- resolution or escalation

It also keeps:

- Guided Demo mode that works immediately
- live Anthropic mode through an in-app Settings screen
- local session saving on the Mac
- plain-language templates for social science and law users

## How to get the app

You do not need to install Xcode locally.

1. Open this repository on GitHub.
2. Click the **Actions** tab near the top of the page.
3. In the left sidebar, click **Build macOS App**.
4. If a build has already run successfully, click the latest run.
5. If no build has run yet, click **Run workflow**, then click the green **Run workflow** button.
6. Wait for the job to finish.
7. On the workflow run page, scroll to **Artifacts**.
8. Click **LoopholeUI-macOS-app** to download the zip file.
9. Open the downloaded zip to unzip `LoopholeUI.app`.
10. Drag `LoopholeUI.app` into your Applications folder if you want to keep it there.

## If macOS blocks the app the first time

Because this app is unsigned and meant for personal use, macOS may warn that it cannot verify the developer.

The beginner-friendly way to open it is:

1. In Finder, locate `LoopholeUI.app`.
2. Control-click the app.
3. Choose **Open**.
4. Click **Open** again in the warning dialog.

If that option does not appear:

1. Try opening the app once normally.
2. Open **System Settings**.
3. Go to **Privacy & Security**.
4. Scroll down until you see a message about `LoopholeUI.app` being blocked.
5. Click **Open Anyway**.
6. Confirm by clicking **Open**.

## What is in this repo

- A native macOS app target named `LoopholeUI`
- An Xcode project that GitHub Actions can build into a real `.app`
- A GitHub Actions workflow that zips the finished `.app` and uploads it as an artifact
- The Swift Package manifest is still present, but the GitHub build uses the Xcode project because that is the most reliable path for producing a downloadable Mac app bundle

## Current product direction

This app is designed for non-coders, especially social science and law majors who want to test political, legal, or moral principles using the Loophole method without cloning repos or using Terminal.
