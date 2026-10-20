require "test_helper"

# Settings → Activity (plan: milestone 5): the audit log, newest first, adults only.
class ActivityTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 15, 18)
    people(:wes).update!(email: users(:owner).email)  # the owner's login is Wes's
  end

  test "an adult sees what happened, newest first; a kid does not" do
    sign_in_as users(:owner)
    patch settings_path, params: { household: { name: "The Fixtures" } }
    show = households(:primary)
    show.audit_entries.create!(action: "chore.completed", subject_name: "Homework", actor_name: "Kitchen", created_at: 1.hour.ago)
    get settings_path
    assert_select "a[href=?]", settings_activity_path
    get settings_activity_path
    assert_response :success
    assert_select "li", minimum: 2
    assert_select "li:first-child", text: /Wes.*changed the household.*name/mi
    assert_select "li", text: /Kitchen.*completed Homework/mi
  end

  test "a write from the frame names the screen" do
    show_on_screen(name: "Hall")
    post chore_completions_path(chores(:homework)), as: :turbo_stream
    entry = households(:primary).audit_entries.last
    assert_equal [ "chore.completed", "Hall" ], [ entry.action, entry.actor_name ]
  end
end
