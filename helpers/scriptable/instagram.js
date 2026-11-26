async function instagram() {

  const profilePageRegex = /instagram.com\/(?!(p\/|reel\/|s\/|stories\/|tv\/))/i

  const mediaIdRegex = /(?<="media_id":")[0-9]*(?=")|(?<="initial_media_id":")[0-9]*(?=")/

  const userIdRegex = /(?<="user_id":")[0-9]*(?=")/

  const storyMediaIdRegex = /(?<=story_media_id=)[0-9]*(?=&)/i

  const postIdRegex = /(?<=instagram.com\/(p|reel|s|tv)\/).*(?=\?)/i

  if (!(await loggedIn())) {

    return instagramOutput({ requiresUserLogin: true })
  }

  const [_postId] = postIdRegex.exec(inputUrl) ?? ['story']
  const postId = _postId.replaceAll('/', ' ').trim()

  try {

    const html = await fetchit(inputUrl, 'loadString')

    if (profilePageRegex.test(inputUrl)) {

      const [userId] = userIdRegex.exec(html)
      if (!userId) {
        return scriptError('Missing user ID')
      }

      const [reelsMedia, userInfo] = await Promise.all([
        fetchit(`https://i.instagram.com/api/v1/feed/reels_media/?reel_ids=${userId}`),
        fetchit(`https://i.instagram.com/api/v1/users/${userId}/info/`)
      ])

      if (reelsMedia.status !== 'ok' || userInfo.status !== 'ok') {
        const errorMessage = reelsMedia.message || userInfo.message
        return scriptError(errorMessage || 'Instagram API status is not ok')
      }

      const downloadLinks = []

      if (reelsMedia.reels_media.length > 0) {

        for (const item of reelsMedia.reels_media.at(0).items) {
          const link = extractDownloadLinks(item)
          downloadLinks.push(link)
        }
      }

      return instagramOutput({
        postId,
        downloadLinks: [...downloadLinks.flat(), userInfo.user.hd_profile_pic_url_info.url],
        authorUsername: userInfo.user.username
      })
    } else {

      const [mediaId] = mediaIdRegex.exec(html) || storyMediaIdRegex.exec(inputUrl)
      if (!mediaId) {
        return scriptError('Missing media ID')
      }

      const mediaInfo = await fetchit(`https://i.instagram.com/api/v1/media/${mediaId}/info/`)
      if (mediaInfo.status !== 'ok') {
        return scriptError(mediaInfo.message || 'Instagram API status is not ok')
      }

      const post = mediaInfo.items.at(0)
      const downloadLinks = extractDownloadLinks(post)
      const postAuthor = post.user || post.carousel_media.at(0).user

      return instagramOutput({
        postId,
        downloadLinks: downloadLinks,
        authorUsername: postAuthor.username
      })
    }
  } catch (error) {
    return scriptError(error.message || 'Connectivity')
  }

  async function loggedIn() {
    const req = new Request('https://www.instagram.com/')
    await req.load()
    return req.response.cookies.some((cookie) => /sessionid/.test(cookie.name))
  }

  function instagramOutput(output) {

    const defaultOutput = {
      platform: 'Instagram',
      postId: '',
      authorUsername: 'instagram_user',
      downloadLinks: [],
      requiresUserLogin: false
    }
    return { ...defaultOutput, ...output }
  }

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
}
