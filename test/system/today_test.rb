require "application_system_test_case"

# The Today view in the browser: the clock and hero come from the server's time, the slideshow
# runs, and the hero countdown ticks locally.
class TodayTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
  end

  test "clock, hero and slideshow render from the server's clock" do
    assert_selector "#today-clock .h-time", text: /3:18\s*PM/
    assert_selector "#today-clock .h-date", text: /wednesday\s+october 14/i
    assert_selector "#today-hero .h-hero-title", text: "Piano lesson"
    assert_selector "#today-hero .h-hero-count", text: /27\s*min/i
    assert_selector "#today-hero .pill--soon", text: /leave in 15 min/i
    assert_selector "#today-photo .h-photo-stage .slide", wait: 5
  end

  test "the hero countdown is recomputed on the minute" do
    assert_selector "#today-hero .h-hero-count", text: /27\s*min/i
    # Jump the browser clock forward 10 minutes and fire the shell's minute event.
    execute_script(<<~JS)
      const stage = document.getElementById("stage")
      const ctrl = window.shell
      const detail = { now: new Date(Date.now()) }
      import("dashboard/clock").then((clock) => {
        clock.setBase(clock.epoch() + 10 * 60000, clock.offset())
        stage.dispatchEvent(new CustomEvent("shell:minute", { bubbles: true, detail }))
      })
    JS
    assert_selector "#today-hero .h-hero-count", text: /17\s*min/i
    assert_selector "#today-hero .pill--soon", text: /leave in 5 min/i
  end

  test "tapping the hero area for the calendar switches views" do
    find("#today-clock").click
    assert_selector "#view-calendar.is-active"
  end
end
