require "application_system_test_case"

# Home control and Photos in the browser: optimistic tiles, scenes with Undo, the lights sheet,
# the thermostat, and the photo chrome.
class ControlTest < ApplicationSystemTestCase
  setup { show_on_screen }

  def open_control
    find(".rail-item[data-go=control]").click
    assert_selector "#view-control.is-active"
  end

  test "tapping a light toggles it at once and the summary follows" do
    open_control
    tile = "#device_#{devices(:island).id}"
    assert_no_selector "#{tile}.is-on"
    find(tile).click
    assert_selector "#{tile}.is-on .tile-state", text: "100%"
    assert_selector "#control-sum .sum[data-sum=lights] b", text: "4"
    assert_selector "#room_#{rooms(:kitchen).id}_count", text: /2 on/i
    assert devices(:island).reload.on?
  end

  test "an unreachable light snaps back with a red toast" do
    open_control
    tile = "#device_#{devices(:string_lights).id}"
    find(tile).click
    assert_selector "#toasts .toast--error", text: /couldn’t reach\s*string lights/i
    assert_no_selector "#{tile}.is-on"
  end

  test "a scene applies, highlights, and Undo restores" do
    open_control
    find("#control-scenes .scene", text: /movie/i).click
    assert_selector "#control-scenes .scene.is-on", text: /movie/i
    assert_no_selector "#device_#{devices(:pendants).id}.is-on"
    assert_selector "#toasts .toast-msg", text: /movie\s*scene on/i
    find("#toasts .toast-undo").click
    assert_selector "#device_#{devices(:pendants).id}.is-on"
    assert_no_selector "#control-scenes .scene.is-on"
  end

  test "the lights summary opens the sheet and Turn everything off works" do
    open_control
    find("#control-sum .sum[data-sum=lights]").click
    assert_selector "#sheetLayer.is-open .sheet--wide .sheet-h", text: /lights/i
    assert_selector "#sheetLayer .tiles--sheet .tile", count: 5
    click_on "Turn everything off"
    assert_no_selector "#sheetLayer.is-open"
    assert_selector "#control-sum .sum[data-sum=lights] b", text: "0"
    assert_selector "#toasts .toast-msg", text: /turned off 3 lights/i
  end

  test "the thermostat steps" do
    open_control
    find("#control-climate [data-delta='0.5']").click
    assert_selector "#control-climate .th-set .num", text: "22°"
    assert_selector "#control-sum .sum[data-sum=climate] small", text: /heating to 22°/i
  end

  test "the thermostat's − and + stay round beside the big setpoint" do
    open_control
    sizes = evaluate_script("Array.from(document.querySelectorAll('#view-control .th-btn')).map(b => { const r = b.getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height)] })")
    assert_equal 2, sizes.size
    sizes.each { |w, h| assert_equal h, w, "thermostat button #{w}×#{h} is not round" }
    main = evaluate_script("(() => { const m = document.querySelector('#view-control .th-main'); return [m.scrollWidth, m.clientWidth] })()")
    assert main[0] <= main[1], "the setpoint row overflows its card (#{main[0]} > #{main[1]})"
  end

  test "photos: layout toggle, favourite and the loud captions" do
    # The slideshow shuffles the pool, so which photo is showing is random; with no favourites
    # at all, the first tap can only add one (a favourite showing would be removed instead).
    # The page carries the pool, so reload it after clearing.
    Photo.update_all(favorite: false)
    visit root_path
    find(".rail-item[data-go=photos]").click
    assert_selector "#view-photos.is-active .ph-stage .slide", wait: 5
    find("#view-photos [data-layout=polaroid]").click
    assert_selector "#view-photos [data-layout=polaroid].is-on"
    assert_selector "#view-photos .ph-stage .slide--polaroid", wait: 5
    find("#view-photos .ph-btn--fav").click
    assert_selector "#view-photos .ph-btn--fav.is-on"
    assert_selector "#toasts .toast-msg", text: /added to favourites/i
    find("#view-photos .ph-zone--c").click
    assert_selector "#view-photos .photos.is-loud"
  end
end

# Unlocking from the frame asks for an adult's PIN (plan: gap review): the hold opens the pad,
# the right digits unlock, wrong ones do not.
class UnlockPinBrowserTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    households(:primary).update!(demo: false)
    people(:wes).update!(pin: "2468")
    devices(:front_door).deviceable.update!(locked: true)
    show_on_screen
    find(".rail-item[data-go=control]").click
    assert_selector "#view-control.is-active"
  end

  def hold(selector)
    el = find(selector)
    page.driver.browser.action.click_and_hold(el.native).pause(duration: 1.3).release.perform
  end

  test "holding a lock opens the PIN pad; the right PIN unlocks, a wrong one is refused" do
    tile = "#device_#{devices(:front_door).id}"
    hold(tile)
    assert_selector "#sheetLayer.is-open .pin-pad", wait: 5
    assert devices(:front_door).reload.locked?, "nothing moved yet"
    %w[0 0 0 0].each { |k| find(".pin-key", text: k, match: :first).click }
    find(".pin-key--go").click
    assert_selector "#sheetLayer.is-open .pin-pad .pin-error", text: /not an adult/i, wait: 5
    assert devices(:front_door).reload.locked?
    %w[2 4 6 8].each { |k| find(".pin-key", text: k).click }
    find(".pin-key--go").click
    assert_selector "#{tile}.is-warn", wait: 5
    assert_not devices(:front_door).reload.locked?
    assert_selector "#toasts .toast", text: /unlocked/i
  end
end
