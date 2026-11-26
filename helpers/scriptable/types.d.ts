export interface DownloadLink {
  url: string
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
