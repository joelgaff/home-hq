require "application_system_test_case"

# Not an assertion suite: with PHONE_SHOTS=1 it saves a screenshot of every view at phone size
# under tmp/screenshots/phone-*.png, for checking the phone layer against the mockups.
class PhoneScreensTest < ApplicationSystemTestCase
  setup do
    skip "set PHONE_SHOTS=1 to capture the phone screens" unless ENV["PHONE_SHOTS"]
    travel_to Time.utc(2026, 10, 14, 15, 18)
    fit_viewport_to(PHONE_SIZE)
    visit new_session_path
    page.save_screenshot(Rails.root.join("tmp/screenshots/phone-login.png").to_s)
    sign_in_on_phone users(:owner)
  end

  test "capture every view" do
    %w[home calendar tasks shopping control photos people].each do |view|
      execute_script("window.shell.go('#{view}')")
      assert_selector "#view-#{view}.is-active"
      sleep 0.6
      page.save_screenshot(Rails.root.join("tmp/screenshots/phone-#{view}.png").to_s)
    end
    { "settings" => settings_path, "settings-people" => settings_people_path, "settings-chores" => settings_chores_path,
      "settings-chore-form" => edit_settings_chore_path(chores(:homework)), "settings-store" => settings_store_path(stores(:costco)) }.each do |name, path|
      visit path
      page.save_screenshot(Rails.root.join("tmp/screenshots/phone-#{name}.png").to_s)
    end
  end
end
