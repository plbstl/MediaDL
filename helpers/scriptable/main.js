var inputUrl = args.shortcutParameter

if (!inputUrl) {
  return scriptError('An empty URL was passed in')
}

if (/instagram.com\//.test(inputUrl)) {
  return await instagram()
}

return scriptError('Unsupported platform')
Script.complete()

function scriptError(msg) {
  return { errorMessage: msg, hasError: true }
}

async function fetchit(url, loadAction = 'loadJSON') {
  const req = new Request(url)

  req.headers = { ...req.headers, 'x-ig-app-id': '936619743392459' }
  return await req[loadAction]()
}
