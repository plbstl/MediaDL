export interface DownloadLink {
  /** Direct link to raw file */
  url: string
  /** Creation date of post */
  timestamp: number
}

export interface ScriptableOutput {
  platform: 'Instagram'
  postId: string
  authorUsername: string
  downloadLinks: DownloadLink[]
}

export interface InstagramOutput extends ScriptableOutput {
  requiresUserLogin: boolean
  platform: 'Instagram'
}
