// SAVE TO PHOTOS - Instagram
// Author: @plbstl

// This script is executed using Apple's JavaScriptCore engine and APIs provided by Scriptable.
// See: https://docs.webkit.org/Deep%20Dive/JSC/JavaScriptCore.html
// See: https://docs.scriptable.app/

async function instagram() {
  /******************************************************************************
   * Constants
   *****************************************************************************/

  /**
   * If the passed-in URL does NOT contain `/p/`, `/reel/`, `/s/`, `/stories/`,
   * or `/tv/` right after the domain name, it is most likely a user profile.
   */
  const profilePageRegex = /instagram.com\/(?!(p\/|reel\/|s\/|stories\/|tv\/))/i

  /**
   * Check for `"media_id":"<id>"` or `"initial_media_id":"<id>"`,
   * and match only the `<id>`, against the webpage HTML
   */
  const mediaIdRegex = /(?<="media_id":")[0-9]*(?=")|(?<="initial_media_id":")[0-9]*(?=")/

  /** Check for `"user_id":"<id>"`, and match only the `<id>`, against the webpage HTML */
  const userIdRegex = /(?<="user_id":")[0-9]*(?=")/

  /** Check for `story_media_id=<id>&`, and match only the `<id>`, against the input URL */
  const storyMediaIdRegex = /(?<=story_media_id=)[0-9]*(?=&)/i

  /******************************************************************************
   * Main
   *****************************************************************************/

  // Check if the user is signed in to Instagram
  if (!(await loggedIn())) {
    // Exit here and prompt the user to log in
    return instagramOutput({ 'User is not logged in': true })
  }

  try {
    // Fetch webpage of the inputted URL as text
    const html = await fetchit(inputUrl, 'loadString')

    // Check if the inputted URL is a profile page
    if (profilePageRegex.test(inputUrl)) {
      // Extract the ID of the inputted user profile
      const [userId] = userIdRegex.exec(html)
      if (!userId) {
        return scriptError('Missing user ID')
      }

      // Check if the inputted user profile has stories posted
      // Why? Because we don't want to prompt the user when the sane thing to
      // do is to auto-download the display picture of the inputted user profile

      // Fetch the inputted user profile's display picture and stories
      const [reelsMedia, userInfo] = await Promise.all([
        fetchit(`https://i.instagram.com/api/v1/feed/reels_media/?reel_ids=${userId}`),
        fetchit(`https://i.instagram.com/api/v1/users/${userId}/info/`)
      ])

      if (reelsMedia.status !== 'ok' || userInfo.status !== 'ok') {
        const errorMessage = reelsMedia.message || userInfo.message
        return scriptError(errorMessage || 'Instagram API status is not ok')
      }

      // Check if there are stories available
      if (reelsMedia.reels_media.length > 0) {
        // Extract all the download links to the stories
        const downloadLinks = []
        for (const item of reelsMedia.reels_media.at(0).items) {
          const link = extractDownloadLinks(item)
          downloadLinks.push(link)
        }

        // Collate an output and exit
        return instagramOutput({
          'Download links': downloadLinks.flat(),
          'Download link to profile picture': userInfo.user.hd_profile_pic_url_info.url,
          'Ask to download only profile pic': true,
          "Post Author's username": userInfo.user.username
        })
      } else {
        // Just return the display picture of the inputted user profile
        // Collate an output and exit
        return instagramOutput({
          'Download links': [userInfo.user.hd_profile_pic_url_info.url],
          "Post Author's username": user.username
        })
      }
    } else {
      // This block indicates that this is an image, reel, album (carousel) or story highlight

      // Extract the media ID of the post or story highlight
      const [mediaId] = mediaIdRegex.exec(html) || storyMediaIdRegex.exec(inputUrl)
      if (!mediaId) {
        return scriptError('Missing media ID')
      }

      // Fetch information about the post using its media ID
      const mediaInfo = await fetchit(`https://i.instagram.com/api/v1/media/${mediaId}/info/`)
      if (mediaInfo.status !== 'ok') {
        return scriptError(mediaInfo.message || 'Instagram API status is not ok')
      }

      // Extract the relevant download link(s)
      const post = mediaInfo.items.at(0)
      const downloadLinks = extractDownloadLinks(post)
      const postAuthor = post.user || post.carousel_media.at(0).user

      // Collate an output and exit
      return instagramOutput({
        'Download links': downloadLinks,
        "Post Author's username": postAuthor.username
      })
    }
  } catch (error) {
    return scriptError(error.message || 'Connectivity')
  }

  /******************************************************************************
   * Helpers
   *****************************************************************************/

  /**
   * Checks if the user is logged in to Instagram.
   * @returns {Promise<boolean>} `true` if the user is logged in, otherwise `false`
   */
  async function loggedIn() {
    const req = new Request('https://www.instagram.com/')
    await req.load()
    return req.response.cookies.some((cookie) => /sessionid/.test(cookie.name))
  }

  /**
   * Exit this script and return the passed in arg as output.
   * @param {Partial<InstagramOutput>} output Result to send back to Siri Shortcuts
   * @returns
   */
  function instagramOutput(output) {
    /** @type {InstagramOutput} */
    const defaultOutput = {
      'Download links': [],
      'Download link to profile picture': '',
      'Ask to download only profile pic': false,
      'User is not logged in': false,
      "Post Author's username": 'instagram_user'
    }
    return { ...defaultOutput, ...output }
  }

  /**
   * Extract relevant download URLs from an Instagram post or story.
   *
   * We are retrieving the highest quality available for every post or story.
   * This is usually the first item in the URLs list.
   * @param {object} post Instagram post or story to retrieve links from
   * @returns {DownloadLink[]} An array of download URLs
   */
  function extractDownloadLinks(post) {
    const IMAGE = 1
    const VIDEO = 2
    const CAROUSEL = 8

    switch (post.media_type) {
      case IMAGE:
        return [
          {
            url: post.image_versions2.candidates.at(0).url,
            timestamp: post.taken_at
          }
        ]

      case VIDEO:
        return [
          {
            url: post.video_versions.at(0).url,
            timestamp: post.taken_at
          }
        ]

      case CAROUSEL:
        const links = []
        for (const carouselPostItem of post.carousel_media) {
          const link = extractDownloadLinks(carouselPostItem)
          links.push(link)
        }
        return links.flat()

      default:
        return []
    }
  }

  /**
   * @typedef {Object} DownloadLink
   * @property {string} url Direct link to raw file
   * @property {number} timestamp Creation date of post
   */

  /**
   * @typedef {{
   * 'Download links': DownloadLink[],
   * 'Download link to profile picture': string,
   * 'Ask to download only profile pic': boolean,
   * 'User is not logged in': boolean
   * Post Author's username": string
   * }} InstagramOutput
   */
}
