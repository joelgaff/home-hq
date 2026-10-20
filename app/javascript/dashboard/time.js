// Formatting for wall-clock Dates from clock.js (UTC fields = household local time).
const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const MON_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "June", "July", "Aug", "Sept", "Oct", "Nov", "Dec"]

export function hours(d) { return d.getUTCHours() }
export function minutes(d) { return d.getUTCMinutes() }

// The household's clock setting (the shell sets it from the page): "12" or "24".
let clock24 = false
export function setClockFormat(format) { clock24 = format === "24" }

export function time(d, ampm) {
  const h = hours(d), m = minutes(d), mm = (m < 10 ? "0" : "") + m
  if (clock24) return (h < 10 ? "0" : "") + h + ":" + mm
  const s = (h % 12 || 12) + ":" + mm
  return ampm === false ? s : s + " " + (h >= 12 ? "PM" : "AM")
}

export function ampm(d) { return clock24 ? "" : (hours(d) >= 12 ? "PM" : "AM") }
export function day(d) { return DAYS[d.getUTCDay()] }
export function dayShort(d) { return DAYS[d.getUTCDay()].slice(0, 3) }
export function month(d) { return MONTHS[d.getUTCMonth()] }
export function monthShort(d) { return MON_SHORT[d.getUTCMonth()] }
export function date(d) { return d.getUTCDate() }

export function mins(m) {
  m = Math.max(0, Math.round(m))
  if (m < 60) return m + " min"
  const h = Math.floor(m / 60), r = m % 60
  return h + " hr" + (r ? " " + r + " min" : "")
}

export function minuteKey(d) { return Math.floor(d.getTime() / 60000) }
