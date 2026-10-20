require "test_helper"

# Calendar rules from docs/ui-spec.md §1.1-1.2 and the plan's calendar decisions.
class EventTest < ActiveSupport::TestCase
  setup do
    @household = households(:primary)
    @today = Date.new(2026, 10, 14)
  end

  test "an event for everyone is a family event, coloured black" do
    assert events(:dinner).family?
    assert_not events(:dentist).family?
    assert_equal "Family", events(:dinner).color_person.name
  end

  test "a shared event takes the colour of the first person listed" do
    haircuts = @household.events.create!(title: "Haircuts", starts_at: Time.utc(2026, 10, 16, 13), ends_at: Time.utc(2026, 10, 16, 13, 45))
    haircuts.attendees.create!(person: people(:skidmark))
    haircuts.attendees.create!(person: people(:buzzsaw))
    assert_equal %w[Skidmark Buzzsaw], haircuts.reload.attending_people.map(&:name)
    assert_equal "Skidmark", haircuts.color_person.name
  end

  test "leave-by is the start minus travel" do
    assert_equal Time.utc(2026, 10, 14, 16, 10), events(:soccer).leave_by
    assert_equal Time.utc(2026, 10, 15, 7, 0), events(:gym_tomorrow).leave_by
  end

  test "timed events on a day are sorted by start, longer first on ties" do
    titles = @household.timed_events_on(@today).map(&:title)
    assert_equal [ "Dentist", "Piano lesson", "Soccer practice", "Dinner at Nonna's" ], titles
  end

  test "timed events can be scoped to one person" do
    assert_equal [ "Dentist", "Soccer practice", "Dinner at Nonna's" ], @household.timed_events_on(@today, person: people(:buzzsaw)).map(&:title)
  end

  test "all-day events use an exclusive end so multi-day ones span the right days" do
    assert_equal [ "Pajama Day at school" ], @household.all_day_events_on(@today).map(&:title)
    assert_equal [ "Wes in Montréal" ], @household.all_day_events_on(@today + 1).map(&:title)
    assert_equal [ "Wes in Montréal" ], @household.all_day_events_on(@today + 3).map(&:title)
    assert_empty @household.all_day_events_on(@today + 4)
    assert_equal 3, events(:montreal).span_days
    assert_equal 2, events(:montreal).day_number_on(@today + 2)
  end

  test "the next event is the earliest remaining leave-by today" do
    # At 15:18 piano (16:10 leave-by after travel? no: 15:33) beats soccer (16:10) and dinner (18:10).
    assert_equal "Piano lesson", @household.next_event(at: Time.utc(2026, 10, 14, 15, 18)).title
    # At 15:50 piano has started; soccer leaves at 16:10, dinner at 18:10.
    assert_equal "Soccer practice", @household.next_event(at: Time.utc(2026, 10, 14, 15, 50)).title
    assert_nil @household.next_event(at: Time.utc(2026, 10, 14, 20, 0))
  end

  test "demo-only events stay out unless the busy calendar mode is on" do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    assert_not_includes @household.timed_events_on(@today).map(&:title), "Plumber window"
    assert_includes @household.timed_events_on(@today, mode: "busy").map(&:title), "Plumber window"
    assert_empty @household.timed_events_on(@today, mode: "empty")
    assert_equal [ "Pajama Day at school" ], @household.all_day_events_on(@today, mode: "empty").map(&:title)
  end

  test "an event needs a title and an end after its start" do
    event = @household.events.new(title: "", starts_at: Time.utc(2026, 10, 14, 10), ends_at: Time.utc(2026, 10, 14, 9))
    assert_not event.valid?
    assert_includes event.errors.attribute_names, :title
    assert_includes event.errors.attribute_names, :ends_at
  end

  test "an event with nobody listed is everyone's, in the family style" do
    event = households(:primary).events.create!(title: "Flu shots", starts_at: Time.utc(2026, 10, 14, 19), ends_at: Time.utc(2026, 10, 14, 20))
    assert event.family?
    assert_equal households(:primary).family, event.color_person
  end
end
