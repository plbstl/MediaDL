export type InstagramOutput = {
  downloadLinks: DownloadLink[]
  requiresUserLogin: boolean
  authorUsername: string
}

export interface DownloadLink {
  /** Direct link to raw file */
  url: string
  /** Creation date of post */
  timestamp: number
}
