require "test_helper"

# Auto-relock (plan: milestone 6): a door unlocked from the doorbell takeover relocks after two
# minutes unless someone locked it already.
class RelockJobTest < ActiveJob::TestCase
  setup do
    @lock = devices(:front_door)
    @lock.deviceable.update!(locked: false)
    Current.household = households(:primary)
  end

  teardown { Current.reset }

  test "relocks an unlocked door and logs it; a locked door is left alone" do
    RelockJob.perform_now(@lock.id)
    assert @lock.reload.locked?
    assert_equal "device.relocked", households(:primary).audit_entries.last.action
    count = households(:primary).audit_entries.count
    RelockJob.perform_now(@lock.id)
    assert_equal count, households(:primary).audit_entries.count
  end

  test "unlocking with relock from the frame schedules the job" do
    people(:wes).update!(pin: "2468")
    @lock.deviceable.update!(locked: true)
    assert_enqueued_with(job: RelockJob, args: [ @lock.id ]) do
      @lock.unlock_for_a_while!(adult: people(:wes))
    end
    assert_not @lock.reload.locked?
  end
end
