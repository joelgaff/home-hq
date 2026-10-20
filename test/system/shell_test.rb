require "application_system_test_case"

# The shell (docs/ui-spec.md §0): one page, rail switches views on pointerdown without a page
# load, hash routes, keyboard shortcuts, and the rail clock ticking from the server's time.
class ShellTest < ApplicationSystemTestCase
  setup { show_on_screen }

  test "the rail switches views in place and keeps the hash" do
    assert_selector "#view-home.is-active"
    assert_selector ".rail-item.is-active[data-go=home]"

    find(".rail-item[data-go=calendar]").click
    assert_selector "#view-calendar.is-active"
    assert_no_selector "#view-home.is-active"
    assert_equal "#calendar", evaluate_script("location.hash")

    # No navigation happened: the stage element is the same node.
    assert evaluate_script("window.__stageMark === undefined && (window.__stageMark = 1, true)")
    find(".rail-item[data-go=shopping]").click
    assert_selector "#view-shopping.is-active"
    assert_equal 1, evaluate_script("window.__stageMark")
  end

  test "an unknown hash falls back to home" do
    visit root_path(anchor: "nonsense")
    assert_selector "#view-home.is-active"
    assert_equal "#home", evaluate_script("location.hash")
  end

  test "number keys jump between views" do
    find("body").send_keys("3")
    assert_selector "#view-tasks.is-active"
    find("body").send_keys("1")
    assert_selector "#view-home.is-active"
  end

  test "a 24-hour household gets a 24-hour rail clock" do
    households(:primary).update!(clock_format: "24")
    visit root_path
    assert_selector "#railClock b", text: /\A\d{2}:\d{2}\z/
    assert_no_selector "#railClock span", text: /AM|PM/
  end

  test "the rail clock shows the household's wall-clock time" do
    assert_selector "#railClock b", text: /\A\d{1,2}:\d{2}\z/
    assert_selector "#railClock span", text: /\A(AM|PM)\z/
  end
end

# Per-screen settings (plan: per-screen settings): the frame boots on its default view and the
# idle machine returns to it; the hash only picks the view on the app layout.
class ScreenDefaultViewTest < ApplicationSystemTestCase
  test "the frame boots on its default view whatever the hash says, and idles back to it" do
    screen = show_on_screen
    screen.update!(default_view: "calendar")
    assert_selector "#stage[data-shell-view-value=calendar]", visible: :all, wait: 10  # the setting change reloaded this page
    visit "/up"  # then a cold start: a visit that only changes the hash is a same-document navigation
    visit root_path(anchor: "home")
    assert_selector "#view-calendar.is-active"
    assert_equal "#calendar", evaluate_script("location.hash")

    find(".rail-item[data-go=shopping]").click
    assert_selector "#view-shopping.is-active"
    execute_script("window.shell.setIdle(1, 100); window.shell.idleSeconds = 0")
    assert_selector "#view-calendar.is-active", wait: 5
  end
end
