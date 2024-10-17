// SAVE TO PHOTOS
// Author: @plbstl

// This script is executed using Apple's JavaScriptCore engine and APIs provided by Scriptable.
// See: https://docs.webkit.org/Deep%20Dive/JSC/JavaScriptCore.html
// See: https://docs.scriptable.app/

/******************************************************************************
 * Setup
 *****************************************************************************/

/**
 * **NOTE: THIS VARIABLE IS READ-ONLY.**
 *
 * A `var` is used so that it is hoisted to the top of the generated `scriptable.js` module.
 */
var inputUrl = args.shortcutParameter

if (!inputUrl) {
  return scriptError('An empty URL was passed in')
}

/******************************************************************************
 * Main
 *****************************************************************************/

if (/instagram.com\//.test(inputUrl)) {
  return await instagram()
}

return scriptError('Unsupported platform')
Script.complete()

/******************************************************************************
 * Helpers
 *****************************************************************************/

/**
 * Exit this script with an error.
 * @param {string} msg Informational error message to show user
 */
function scriptError(msg) {
  return { 'Error message': msg, 'An error occurred': true }
}

/**
 * Perform a URL request and return the response in an appropriate format.
 * @param {string} url URL to send request to
 * @param {'load'|'loadString'|'loadJSON'|'loadImage'} [loadAction] How the response body should be loaded
 * @returns `Data`, `Image`, `string` or `object` based on what the `loadAction` is.
 */
async function fetchit(url, loadAction = 'loadJSON') {
  const req = new Request(url)
  // Use `x-ig-app-id` or a mobile `user-agent` header
  req.headers = { 'x-ig-app-id': '936619743392459' }
  return await req[loadAction]()
}
