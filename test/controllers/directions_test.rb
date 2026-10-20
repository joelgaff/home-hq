require "test_helper"

# "Send directions to phone" v1 (plan: second gap review): tapping the location on the event sheet
# shows a QR code of a maps link for the address; a phone camera opens Apple or Google Maps.
class DirectionsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
  end

  test "the sheet's location row leads to a QR code for the address" do
    get event_path(events(:piano))
    assert_select "a[href=?]", directions_event_path(events(:piano)), text: /Ms. Park's Studio/
    get directions_event_path(events(:piano))
    assert_response :success
    assert_select "turbo-frame#sheet .evs-qr svg", 1
    assert_select ".evs-directions b", text: "Ms. Park's Studio"
    assert_select ".evs-directions a[href=?]", "https://maps.apple.com/?daddr=Ms.+Park%27s+Studio"
    assert_select "a[href=?]", event_path(events(:piano)), text: /back/i
  end

  test "an event with no location has no directions" do
    event = households(:primary).events.create!(title: "Call", starts_at: Time.utc(2026, 10, 14, 18), ends_at: Time.utc(2026, 10, 14, 19))
    get directions_event_path(event)
    assert_response :not_found
  end
end
