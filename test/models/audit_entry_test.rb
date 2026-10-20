require "test_helper"

# The audit log (plan: second gap review; milestone 5): settings changes, chore completions and
# unlocks, each with who did it (a person, a screen, or the PIN's adult) and when.
class AuditEntryTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    @household = households(:primary)
    Current.household = @household
    people(:wes).update!(email: users(:owner).email)  # the owner's login is Wes's
  end

  teardown { Current.reset }

  test "a chore completion and its undo are logged with the actor" do
    Current.screen = Screen.create!(household: @household, name: "Kitchen")
    completion = chores(:homework).complete!
    entry = @household.audit_entries.last
    assert_equal [ "chore.completed", "Homework", "Kitchen" ], [ entry.action, entry.subject_name, entry.actor_name ]
    completion.undo!
    assert_equal "chore.undone", @household.audit_entries.last.action
  end

  test "an unlock is logged with the PIN's adult, a lock with the screen" do
    Current.screen = Screen.create!(household: @household, name: "Kitchen")
    Current.pin_person = people(:wes)
    devices(:front_door).apply(locked: false)
    entry = @household.audit_entries.last
    assert_equal [ "device.unlocked", "Front Door", "Wes" ], [ entry.action, entry.subject_name, entry.actor_name ]
    Current.pin_person = nil
    devices(:front_door).apply(locked: true)
    assert_equal [ "device.locked", "Kitchen" ], [ @household.audit_entries.last.action, @household.audit_entries.last.actor_name ]
  end

  test "a scene and the household's settings are logged" do
    Current.user = users(:owner)
    scenes(:movie).activate!
    assert_equal "scene.activated", @household.audit_entries.last.action
    @household.update!(clock_format: "24")
    entry = @household.audit_entries.last
    assert_equal [ "household.updated", { "clock_format" => [ "12", "24" ] } ], [ entry.action, entry.details["changes"] ]
    assert_equal "Wes", entry.actor_name, "the login's person"
  end

  test "people, chores, routines, stores, calendars and screens log their changes" do
    Current.user = users(:owner)
    person = @household.people.create!(name: "Biscuit", color: "#111111")
    assert_equal [ "person.created", "Biscuit" ], [ @household.audit_entries.last.action, @household.audit_entries.last.subject_name ]
    person.update!(name: "Biscuits")
    assert_equal "person.updated", @household.audit_entries.last.action
    person.destroy
    assert_equal [ "person.removed", "Biscuits" ], [ @household.audit_entries.last.action, @household.audit_entries.last.subject_name ]
    @household.calendar_sources.create!(name: "Fam", url: "https://x.test/a.ics")
    assert_equal "calendar_source.created", @household.audit_entries.last.action
    Screen.create!(household: @household, name: "Hall").update!(default_view: "calendar")
    assert_equal "screen.updated", @household.audit_entries.last.action
  end

  test "entries older than ninety days are pruned" do
    @household.audit_entries.delete_all
    @household.audit_entries.create!(action: "x", created_at: 100.days.ago)
    @household.audit_entries.create!(action: "y", created_at: 10.days.ago)
    AuditEntry.prune!
    assert_equal [ "y" ], AuditEntry.where(household: @household).pluck(:action)
  end
end
