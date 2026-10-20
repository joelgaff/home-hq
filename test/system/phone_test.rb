require "application_system_test_case"

# The phone layer (plan: Small screens; the approved mockups): under 700 px the rail is a
# five-tab bar, taps are clicks, and the frame-only behaviours (idle, ambient, demo) are off.
class PhoneTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    sign_in_on_phone users(:owner)
  end

  test "the rail is a five-tab bar and the stage fills the phone" do
    assert_selector "#rail .rail-item", visible: :visible, count: 5
    assert_no_selector "#rail .rail-item[data-go=photos]", visible: :visible
    assert_no_selector "#rail .rail-item[data-go=people]", visible: :visible
    assert_no_selector "#railClock", visible: :visible
    assert_in_delta 390, evaluate_script("document.getElementById('stage').getBoundingClientRect().width"), 2
    assert_equal "app", evaluate_script("window.shell.layoutValue")
  end

  test "tabs switch views on click" do
    find("#rail .rail-item[data-go=calendar]").click
    assert_selector "#view-calendar.is-active"
    assert_equal "#calendar", evaluate_script("location.hash")
    find("#rail .rail-item[data-go=home]").click
    assert_selector "#view-home.is-active"
  end

  test "Today stacks: clock row with Me, hero, the agenda, then the cards" do
    assert_selector "#view-home .h-me", visible: :visible
    assert_no_selector "#today-lanes", visible: :visible
    assert_no_selector "#today-presence", visible: :visible
    assert_selector "#today-agenda .h-ag", visible: :visible, minimum: 3
    hero_top = evaluate_script("document.getElementById('today-hero').getBoundingClientRect().top")
    agenda_top = evaluate_script("document.getElementById('today-agenda').getBoundingClientRect().top")
    chores_top = evaluate_script("document.getElementById('today-chores').getBoundingClientRect().top")
    assert hero_top < agenda_top, "hero above the agenda"
    assert agenda_top < chores_top, "agenda above the chores card"
    find("#view-home .h-me").click
    assert_selector "#view-people.is-active"
  end

  test "Calendar: the agenda, a person chip, then Day as one column" do
    find("#rail .rail-item[data-go=calendar]").click
    assert_selector "#calendar .cal--agenda .ag-row", minimum: 4
    find("#calendar .cal-chips a", text: "Skidmark").click
    assert_selector "#calendar .cal-chips a.is-on", text: "Skidmark"
    assert_selector "#calendar .ag-row", count: 2
    find("#calendar .cal-head .seg a", text: /\Aday\z/i).click
    assert_selector "#calendar .cal--day .lanes--1 .lane .ev", count: 2
  end

  test "Chores: a chip narrows the lanes to one person and tapping it again shows all" do
    find("#rail .rail-item[data-go=tasks]").click
    assert_selector "#view-tasks .ch-lane", visible: :visible, count: 5
    find("#view-tasks .ch-chips button", text: /buzzsaw/i).click
    assert_selector "#view-tasks .ch-lane", visible: :visible, count: 1
    assert_selector "#view-tasks .ch-lane[data-lane='#{people(:buzzsaw).id}']", visible: :visible
    find("#view-tasks .ch-chips button", text: /buzzsaw/i).click
    assert_selector "#view-tasks .ch-lane", visible: :visible, count: 5
  end

  def top_of(selector)
    evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().top")
  end

  test "Shopping is input-first: the add box and usuals sit above the store toggle and the list" do
    find("#rail .rail-item[data-go=shopping]").click
    assert_selector "#view-shopping .s-input", visible: :visible
    assert top_of("#view-shopping .s-head h1") < top_of("#view-shopping .s-input"), "title above the add box"
    assert top_of("#view-shopping .s-input") < top_of("#view-shopping .s-usuals"), "add box above the usuals"
    assert top_of("#view-shopping .s-usuals") < top_of("#view-shopping .s-stores"), "usuals above the store toggle"
    assert top_of("#view-shopping .s-stores") < top_of("#view-shopping .s-list .s-row"), "store toggle above the list"
  end

  test "Home control stacks: two summary tiles per row, scenes, rooms in two columns, then climate" do
    find("#rail .rail-item[data-go=control]").click
    assert_selector "#view-control .sum", visible: :visible, count: 4
    sums = evaluate_script("Array.from(document.querySelectorAll('#view-control .sum')).map(s => Math.round(s.getBoundingClientRect().top))")
    assert_equal sums[0], sums[1], "first two summary tiles share a row"
    assert sums[2] > sums[0], "third tile on the next row"
    tiles = evaluate_script("Array.from(document.querySelectorAll('#view-control .room .tile')).slice(0, 2).map(t => Math.round(t.getBoundingClientRect().top))")
    assert_equal tiles[0], tiles[1], "two room tiles per row"
    assert top_of("#view-control .hc-rooms") < top_of("#view-control .hc-climate"), "rooms above the climate card"
  end

  test "Photos is full screen with a back button and no tab bar" do
    find("#view-home .h-photo").click
    assert_selector "#view-photos.is-active"
    assert_no_selector "#rail", visible: :visible
    assert_no_selector "#view-photos [data-layout=pair]", visible: :visible
    assert_selector "#view-photos [data-layout=polaroid]", visible: :visible
    find("#view-photos .ph-back").click
    assert_selector "#view-home.is-active"
    assert_selector "#rail", visible: :visible
  end

  test "Me: the avatar opens the person's page and another avatar switches it" do
    find("#view-home .h-me").click
    assert_selector "#view-people.is-active .me-panel.is-picked .me-name", text: "Wes"
    find("#view-people .me-picks [data-pick='#{people(:buzzsaw).id}']").click
    assert_selector "#view-people .me-panel.is-picked .me-name", text: "Buzzsaw"
    assert_selector "#view-people .me-panel", visible: :visible, count: 1
  end

  test "an event sheet fills the phone screen and closes from its X" do
    find("#today-agenda .h-ag", text: "Piano lesson").click
    assert_selector "#sheetLayer.is-open .sheet .evs-band h2", text: "Piano lesson"
    box = evaluate_script("(() => { const r = document.querySelector('#sheetLayer .sheet').getBoundingClientRect(); return [Math.round(r.left), Math.round(r.top), Math.round(r.width), Math.round(r.height)] })()")
    assert_equal [ 0, 0, 390, 844 ], box
    find("#sheetLayer .sheet-x").click
    assert_no_selector "#sheetLayer.is-open"
  end

  test "the Me picks clear the back button, on a phone and on a desktop" do
    find("#view-home .h-me").click
    assert_me_picks_clear_the_back_button
    # The same person in a desktop-sized browser: the app layout without the phone layer.
    fit_viewport_to(FRAME_SIZE)
    visit root_path(anchor: "people")
    assert_me_picks_clear_the_back_button
  end

  def assert_me_picks_clear_the_back_button
    assert_selector "#view-people.is-active .me-pick.is-on"
    back_right = evaluate_script("document.querySelector('#view-people .me-back').getBoundingClientRect().right")
    pick_left = evaluate_script("document.querySelector('#view-people .me-pick.is-on').getBoundingClientRect().left")
    assert pick_left - back_right >= 8, "the picked avatar's ring (6px) overlaps the back button"
  end

  test "a desktop browser gets the frame's Today, without the phone-only pieces" do
    fit_viewport_to(FRAME_SIZE)
    visit root_path
    assert_selector "#today-lanes .h-lane", visible: :visible, count: 4
    assert_no_selector "#view-home .h-me", visible: :visible
    assert_no_selector "#today-agenda", visible: :visible
    assert_selector "#rail .rail-item", visible: :visible, count: 7
    assert_selector "#railClock", visible: :visible
  end

  test "frame-only modes and the demo drawer stay off" do
    find("body").send_keys("a")
    find("body").send_keys("d")
    assert_selector "#stage[data-mode=day]"
    assert_no_selector "#demo.is-open"
    assert_no_selector "#toasts .toast:not(.toast--tip)"  # the demo tip does not count
  end
end
