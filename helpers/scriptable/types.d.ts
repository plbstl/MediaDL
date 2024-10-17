export interface DownloadLink {
  /** Direct link to raw file */
  url: string
  /** Creation date of post */
  timestamp: number
}

export interface ScriptableOutput {
  downloadLinks: DownloadLink[]
  authorUsername: string
  platform: 'Instagram'
}

export interface InstagramOutput extends ScriptableOutput {
  requiresUserLogin: boolean
  platform: 'Instagram'
}
