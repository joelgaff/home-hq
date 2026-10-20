require "application_system_test_case"

# With the network gone, the frame boots from the service worker's copy of the last page and
# says so: "Offline · showing data from 3:18 PM" (plan: Offline and stale data).
class OfflineTest < ApplicationSystemTestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
  end

  teardown { set_offline(false) }

  def set_offline(flag)
    page.driver.browser.network_conditions = { offline: flag, latency: 0, download_throughput: -1, upload_throughput: -1 }
  end

  test "the cached page comes back with the stale banner when the network is down" do
    assert_selector "#stage[data-shell-ready]"
    # Let the worker install and take its first copy of the page.
    cached = 20.times.any? do
      evaluate_script("caches.open('hq-v1-pages').then(c => c.match('/')).then(r => !!r)") || (sleep(0.5) && false)
    end
    assert cached, "the worker never cached the page"
    # Chrome's offline emulation does not reach the worker's own fetches: ask it to pretend.
    simulate_offline(true)
    visit root_path
    assert_selector "#stage[data-shell-ready]", wait: 10
    assert_selector "#banners .banner--offline .banner-text b", text: /offline · showing data from 3:18 PM/i, wait: 5
    assert_not_empty evaluate_script("document.body.dataset.offlineSince").to_s, "the cached page carries data-offline-since"

    simulate_offline(false)
    assert_no_selector "#banners .banner--offline", wait: 15
  end

  test "the cached page's banner tells the time in the household's zone, not UTC" do
    households(:primary).update!(time_zone: "Pacific Time (US & Canada)")
    visit root_path
    assert_selector "#stage[data-shell-ready]"
    cached = 20.times.any? do
      evaluate_script("caches.open('hq-v1-pages').then(c => c.match('/')).then(r => !!r)") || (sleep(0.5) && false)
    end
    assert cached, "the worker never cached the page"
    simulate_offline(true)
    visit root_path
    assert_selector "#stage[data-shell-ready]", wait: 10
    # 15:18 UTC is 8:18 AM in Pacific daylight time.
    assert_selector "#banners .banner--offline .banner-text b", text: /showing data from 8:18 AM/i, wait: 5
    simulate_offline(false)
  end

  def simulate_offline(flag)
    execute_script("navigator.serviceWorker.controller.postMessage({ type: 'hq:simulate-offline', value: #{flag} })")
  end

  test "losing the network while running shows the banner; getting it back clears it" do
    assert_selector "#stage[data-shell-ready]"
    set_offline(true)
    execute_script("document.dispatchEvent(new Event('turbo:fetch-request-error', { bubbles: true }))")
    assert_selector "#banners .banner--offline", wait: 5
    set_offline(false)
    assert_no_selector "#banners .banner--offline", wait: 15
  end

  test "a write while offline is refused with a toast and nothing is saved" do
    assert_selector "#stage[data-shell-ready]"
    find(".rail-item[data-go=tasks]").click
    set_offline(true)
    execute_script("window.dispatchEvent(new Event('offline'))")
    assert_selector "#banners .banner--offline", wait: 5
    find("#chores .ch[data-chore='#{chores(:homework).id}']").click
    assert_selector "#toasts .toast.is-in .toast-msg", text: /can.t save while offline/i, wait: 5
    sleep 1
    assert_not ChoreCompletion.exists?(chore: chores(:homework)), "nothing reached the server"
  end

  test "a form button while offline (Undo) is refused the same way" do
    assert_selector "#stage[data-shell-ready]"
    find(".rail-item[data-go=tasks]").click
    find("#chores .ch[data-chore='#{chores(:homework).id}']").click
    assert_selector "#toasts .toast-undo", wait: 5
    assert ChoreCompletion.exists?(chore: chores(:homework))
    set_offline(true)
    execute_script("window.dispatchEvent(new Event('offline'))")
    find("#toasts .toast-undo").click
    assert_selector "#toasts .toast.is-in .toast-msg", text: /can.t save while offline/i, wait: 5
    assert ChoreCompletion.exists?(chore: chores(:homework)), "the undo never left the page"
  end
end
