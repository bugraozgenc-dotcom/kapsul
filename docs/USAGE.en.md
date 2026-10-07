# Kapsül user guide

[Türkçe](USAGE.tr.md) · [Project home](../README.md)

Kapsül is a searchable clipboard history panel for text, links, and images copied on your Mac. It also saves new screenshots while the app is running.

## Install

1. Download `Kapsul-0.4.0-universal.dmg` from the project’s **Releases** page. macOS 14 or later is required; the package includes Apple silicon and Intel code.
2. Open the DMG and drag **Kapsül.app** into **Applications**.
3. Launch Kapsül from **Applications**, then eject the disk image.

This release is ad hoc signed, without a Developer ID signature or Apple notarization. macOS may block the downloaded app. If you trust the source, try opening it, then use **System Settings → Privacy & Security → Open Anyway**. See [Apple’s guide to opening apps safely](https://support.apple.com/en-us/102445) for details.

## Your first item

With Kapsül running, copy text, a link, or an image in another app. The new item appears in the panel. New captures made with macOS screenshot tools appear in the **Screenshot** group. Screenshots taken before the app starts are not imported in bulk.

The clipboard is checked about every 0.7 seconds. Very fast successive copies within that interval may be missed. Capture stops when you quit the app; closing its window lets it keep running. Use the clipboard icon in the menu bar and **Open history panel** to return. The app does not include a launch-at-login setting.

## Find, open, and copy again

- Select **All**, **Pinned**, a content type, or a source in the sidebar. Cards share the same size, with a date and time at the bottom.
- Enter a word or part of a URL in the search field. **⌘F** focuses search. Search matches item text and link values in the selected group; it does not perform OCR on images.
- Click the heading or content of a link card to open its URL in your default browser.
- **Copy** puts the item back on the clipboard. Success appears as a green **Copied** label with a checkmark.
- Hover over or click an image or screenshot to open a larger preview. Its **Copy** button copies the image.
- Right-click a card and select **Pin** to include it in **Pinned**. Use the same menu to unpin it.
- Click **×** at the top right of a card and confirm to delete the item from history. Deletion cannot be undone.

Copying a file in Finder stores a reference to its path. Kapsül does not back up the file’s contents; the stored reference may stop working if the original is moved or deleted.

## Source groups

Built-in sources: **LinkedIn, WhatsApp, Facebook, Instagram, YouTube, Behance, Medium, X, TikTok, Reddit, Pinterest, GitHub, Dribbble, Vimeo, Telegram, and Discord**.

Links are grouped by domain. For text and images copied from some supported desktop apps, the foreground app is also used as a source hint. The website behind plain text copied in a browser cannot always be identified.

To create a group, open **Settings → My sources**, enter a name and comma-separated domains such as `example.com, example.org`, then select **Add source**. Matching subdomains and both existing and new links appear in the group. Removing a custom source keeps its history items. Custom sources use a generic globe icon.

## Settings

| Setting | Behavior |
| --- | --- |
| Language | Türkçe, English, Français, Deutsch, or Español. The panel updates immediately; standard macOS menus may require reopening the app. |
| Appearance | System, Light, or Dark. System follows your Mac’s appearance setting. |
| Retention | 1 month, 3 months, 1 year, or Forever. Expired items and stored images are deleted, including pinned items. Choosing a shorter period asks for confirmation and immediately removes older items. |
| Link previews | Off by default. Enabling previews sends network requests to the linked sites to retrieve titles and thumbnails. Some sites do not provide a preview. |
| Clear history | Permanently deletes all history items and images stored by Kapsül after confirmation. Your custom source groups remain. |

Use the pause button at the top right of the panel or **Pause capture** in the menu bar to stop capture. Select **Resume capture** to continue. Copies and screenshots made while paused are not imported afterward in bulk.

## Data and devices

History, images, and custom sources are stored on this Mac in `~/Library/Application Support/CopyGlass/`. Preferences use macOS user settings. History has no additional application-level encryption; pause capture before copying sensitive content. Clipboard items marked as concealed or transient are skipped, but not every app sets those markers.

Kapsül has no cloud account or phone synchronization service. An item copied on an iPhone may be recorded if it reaches the Mac clipboard through Apple’s Universal Clipboard. This depends on Apple’s requirements; automatic phone transfer has not been verified as a feature of this release.

Brand names and icons belong to their owners; those services do not endorse Kapsül. See the [third-party notice](../Sources/CopyGlass/Resources/NOTICE.txt) for icon attribution.
