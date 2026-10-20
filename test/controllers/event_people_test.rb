require "test_helper"
require "turbo/broadcastable/test_helper"

# The event sheet's "who is it for" override (plan: Calendars, rule 1): tap the people chips to
# change them, "Everyone" for a family event, and "Back to the calendar's" to drop the override.
class EventPeopleTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    show_on_screen
    @event = events(:piano)
  end

  test "the sheet offers every person as a toggle and a reset once overridden" do
    get event_path(@event)
    assert_select "form[action=?]", event_path(@event)
    assert_select ".evs-people button[name='person_ids[]']", households(:primary).people.count
    assert_select ".evs-people button.is-on", @event.attendees.count
    assert_select "button", text: /back to the calendar/i, count: 0
  end

  test "changing the people overrides them, tells the screens, and can be reset" do
    streams = capture_turbo_stream_broadcasts(households(:primary)) do
      patch event_path(@event), params: { person_ids: [ people(:wes).id, people(:claudia).id ] }, as: :turbo_stream
    end
    assert_response :success
    assert_equal %w[Claudia Wes], @event.reload.attending_people.map(&:name).sort
    assert @event.people_overridden?
    assert_equal 1, streams.size
    assert_includes streams.first["targets"].split(","), "today-hero"
    assert_select "turbo-stream[action=replace][target=sheet] button.is-on", 2
    assert_select "turbo-stream[action=pieces][targets*=calendar]", 1

    patch event_path(@event), params: { person_ids: households(:primary).people.ids }, as: :turbo_stream
    assert @event.reload.family?

    patch event_path(@event), params: { reset: "1" }, as: :turbo_stream
    assert_not @event.reload.people_overridden?
  end
end
