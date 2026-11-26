const parameter = String(args.shortcutParameter ?? '')
const boundary = parameter.indexOf('\n')
const postId = boundary < 0 ? '' : parameter.slice(0, boundary).trim()
const transcript = boundary < 0 ? parameter : parameter.slice(boundary + 1)

if (!transcript.trim()) {
  throw new Error('No speech was transcribed.')
}

try {
  const files = FileManager.local()
  const directory = files.joinPath(files.documentsDirectory(), 'MediaDL Transcripts')
  if (!files.fileExists(directory)) files.createDirectory(directory, true)

  const safeId = /^[a-zA-Z0-9_-]{1,80}$/.test(postId) ? postId : 'transcript'
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const baseName = 'Instagram Reel ' + safeId + ' ' + timestamp
  let name = baseName + '.txt'
  let path = files.joinPath(directory, name)
  for (let version = 2; files.fileExists(path); version++) {
    name = baseName + ' (' + version + ').txt'
    path = files.joinPath(directory, name)
  }
  files.writeString(path, transcript)
  Script.setShortcutOutput(path)
} catch (error) {
  console.error(String(error))
  Script.setShortcutOutput(transcript)
  await QuickLook.present('Could not save to On My iPhone / Scriptable / MediaDL Transcripts.\n\n' + transcript)
}
