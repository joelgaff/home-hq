// The dashboard's clock. The frame has no reliable clock of its own and sits in the wrong time
// zone, so the server hands the page its "now" plus the household's UTC offset; everything in
// the browser derives wall-clock time from that and a monotonic timer. Wall-clock Dates returned
// here carry the household's local time in their *UTC* fields: format with getUTCHours() etc.
// (the helpers in time.js do), never the local getters.
let baseMs = Date.now()
let baseAt = performance.now()
let offsetMinutes = 0

export function setBase(ms, offset) {
  baseMs = ms
  baseAt = performance.now()
  offsetMinutes = offset
}

// Real instant (ms since epoch) by the server's reckoning.
export function epoch() {
  return baseMs + (performance.now() - baseAt)
}

// Household wall-clock time as a Date whose UTC fields are the local fields.
export function wall() {
  return new Date(epoch() + offsetMinutes * 60000)
}

// Wall-clock Date for an instant (ms since epoch) in the household's zone.
export function wallAt(ms) {
  return new Date(ms + offsetMinutes * 60000)
}

export function offset() {
  return offsetMinutes
}
