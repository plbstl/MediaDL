<div align="center">

![MediaDL](square.and.arrow.down.fill.png)

# MediaDL

[![Install MediaDL][install-badge]][install-link]
[![Release][gh-release-badge]][gh-release-link]
[![GitHub Issues][gh-issues-badge]][gh-issues-link]
[![GitHub Pull Requests][gh-pulls-badge]][gh-pulls-link]

</div>

<div align="center">

There are **_no ads, unnecessary prompts, tracking or third-party involved_**; everything is **_executed on-device_** and you never have to leave the currently opened application.

</div>

## Supported platforms ✅

- [ ] Facebook
- [x] Instagram (requires sign-in)
- [ ] Pinterest
- [ ] Reddit
- [ ] Snapchat
- [ ] Threads
- [ ] TikTok
- [ ] Tumblr
- [ ] Twitch
- [ ] Vimeo
- [ ] X (formerly Twitter)
- [ ] YouTube

## How to use 🎛️

1. **Share a post:** Click on the relevant Share post icon in the application you're in, to bring up the ShareSheet.

2. **Share to MediaDL:** When the ShareSheet shows, scroll until you find the MediaDL option, then choose it. The first attempt requires you to grant MediaDL permissions to make requests, read through it and click Always Allow.

3. **Continue:** Just like that, MediaDL starts working and you can continue using the application. Prompts to select media might popup if you're downloading multiple items at once.

4. **Media saved:** A visual loader shows the progress and when its done, the file will have been downloaded and placed in the relevant location in your device.

MediaDL works in browsers too.

## Save an Instagram Reel transcript

1. Open [MediaDL Reel Transcript](shortcuts/MediaDL%20Reel%20Transcript.shortcut) on your iPhone and add it to Shortcuts. It uses Scriptable and requires iOS 17 or later.
2. Open Scriptable once, then share a Reel from Instagram to **MediaDL Reel Transcript**. You can also copy the Reel link and run the shortcut from Shortcuts.
3. Open **Files → Browse → On My iPhone → Scriptable → MediaDL Transcripts**. Scriptable creates the folder on the first successful save. If saving fails, the shortcut displays the transcript so you can copy it.

The companion downloads the Reel for transcription and saves only the text. It uses Apple's **Transcribe Audio** action. Select **MediaDL** in the share sheet for regular photo and video downloads.

### Optional offline speech and on-screen text

The [MediaDL Speech companion](ios/) runs transcription and video text recognition on your iPhone. Parakeet Ultra covers English and other supported European languages. Choose a multilingual Whisper model for Hindi. In MediaDL Speech, select one model from the menu and download it, or import its prepared Core ML folder from Files. One installed model is enough. Downloading a Reel still requires network access.

1. Install **MediaDL Speech** using the [build instructions](CONTRIBUTING.md#build-and-verify-the-ios-companion). Open the app and download or import the model you want to use.
2. Duplicate the updated **MediaDL Reel Transcript** in Shortcuts. Give the copy a distinct name.
3. Add **MediaDL Speech → Transcribe Reel (Offline)** after **Encode Media**. Set **Audio** to **Reel Audio**, **Video** to the result of **Download URL** (the action above **Encode Media**), and **Speech Model** to **App Default**. Change the active model in MediaDL Speech.
4. In the final Scriptable action, replace the **Transcript** variable on the second line of **Parameter** with the output of **Transcribe Reel (Offline)**. Leave the first line, which contains the post ID. Delete Apple’s **Transcribe Audio** action from this copy.
5. Share a Reel to the copy. The transcript saves to the same local folder. The base shortcut remains available for Apple transcription.

OCR samples up to 60 frames across the downloaded video, so its timestamps show approximately when text appeared. **[ON-SCREEN]** marks changing text in the speech timeline. Standalone author handles and text seen in at least 60% of analyzed frames, with a minimum of three sightings, appear once in **Persistent On-Screen Notes**. Longer phrases that match nearby speech may be omitted as duplicate captions. Short flashes, stylized text, and scripts unavailable in Vision on your device can be missed. If video recognition fails, the action returns spoken text.

## Installation 📲

1. The Shortcuts app comes preinstalled on Apple devices. In the case that yours is deleted, install [Shortcuts][shortcuts-app-link] from the App Store.
2. Scriptable is used for functionality not yet available in the Shortcuts app. Just like Shortcuts app, you can use it for a lot of other things. Install [Scriptable][scriptable-app-link] from the App Store.
3. Add the [MediaDL][mediadl-shortcut-link] shortcut to your Shortcuts library.
4. Attempt to download media from a supported platform of your choice.

   > If the platform requires you to sign in, **Scriptable** will open a WebView for you to sign in. Sign in and close Scriptable. Future downloads from the selected platform should complete from now on.

5. Select `Always Allow` when prompted for network access to avoid prompts every time you use MediaDL.

## Important Notes 🗒️

- MediaDL will **_never ask_** for your username/email or password. You will be presented with a WebView to login into the relevant official platform using their official methods.

- When using mobile data to access the internet, mobile data has to be turned on for both **Shortcuts** & **Scriptable** in your device settings for downloads to work.

- You have to be signed in to the specific platform to access media private to you.

- You may not have access to sensitive/NSFW content without being signed in to the specific platform.

## Ethics and Disclaimer ⚠️

MediaDL is a tool designed to simplify content downloads from the internet, with **_zero liability_**. You are responsible for what you download, how you use, and distribute that content. Please be mindful of using others’ content and always credit the original creators. Fair use and proper credits benefit everyone.

**MediaDL is NOT a piracy tool** and cannot be used as such. It only downloads free, publicly accessible content, which can also be downloaded through any browser’s developer tools. This tool offers a **convenient**, **clutter-free**, **one-click solution** for repetitive actions.

> This section is gotten from <https://github.com/imputnet/cobalt#ethics-and-disclaimer> and refined a bit.

## Contribute 💡

Check the [Contribution Guide](./CONTRIBUTING.md) for how to contribute to this project.

## License 🤝

<p xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/"><a property="dct:title" rel="cc:attributionURL" href="https://mediadl.plbstl.io">MediaDL</a> is licensed under <a href="https://creativecommons.org/licenses/by-nc-sa/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">CC BY-NC-SA 4.0<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/nc.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/sa.svg?ref=chooser-v1" alt=""></a></p>

**You are free to:**

- **Share** — copy and redistribute the material in any medium or format.

- **Adapt** — remix, transform, and build upon the material.

**Under the following terms:**

- **Attribution** — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.

- **NonCommercial** — You may not use the material for commercial purposes.

- **ShareAlike** — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.

- **No additional restrictions** — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.


[gh-issues-badge]: https://img.shields.io/github/issues/plbstl/MediaDL
[gh-issues-link]: https://github.com/plbstl/MediaDL/issues
[gh-pulls-badge]: https://img.shields.io/github/issues-pr/plbstl/MediaDL
[gh-pulls-link]: https://github.com/plbstl/MediaDL/pulls
[gh-release-badge]: https://img.shields.io/github/v/release/plbstl/MediaDL?sort=semver
[gh-release-link]: https://github.com/plbstl/MediaDL/releases
[install-badge]: https://img.shields.io/badge/install_MediaDL-7c3aed?style=flat-square
[install-link]: https://plbstl.github.io/MediaDL/install


[mediadl-shortcut-link]: https://www.icloud.com/shortcuts/b0792743b4694f28a246f8a31336c960
[scriptable-app-link]: https://apps.apple.com/app/scriptable/id1405459188
[shortcuts-app-link]: https://apps.apple.com/app/shortcuts/id915249334
