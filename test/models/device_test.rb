require "test_helper"

# Home control rules from docs/ui-spec.md §1.1 and §1.6: tile states, the optimistic patch
# contract (apply, or fail for an unreachable device), summaries, scenes with a snapshot for Undo.
class DeviceTest < ActiveSupport::TestCase
  setup { @household = households(:primary) }

  test "tile state labels per device type" do
    assert_equal "80%", devices(:pendants).state_label
    assert_equal "Off", devices(:island).state_label
    assert_equal "60% open", devices(:shade).state_label
    devices(:shade).deviceable.update!(position: 0)
    assert_equal "Closed", devices(:shade).reload.state_label
    assert_equal "Locked", devices(:front_door).state_label
    assert_equal "Closed", devices(:garage).state_label
    devices(:garage).deviceable.update!(state: "opening")
    assert_equal "Opening…", devices(:garage).reload.state_label
  end

  test "a light patch sets on and level; off keeps the last level for the next tap" do
    assert devices(:pendants).apply(on: false)
    assert_not devices(:pendants).reload.on?
    assert_equal 80, devices(:pendants).level
    assert devices(:pendants).apply(on: true, level: 55)
    assert_equal 55, devices(:pendants).reload.level
  end

  test "blinds, locks and the garage take their own patches" do
    assert devices(:shade).apply(position: 100)
    assert_equal "Open", devices(:shade).reload.state_label
    assert devices(:front_door).apply(locked: false)
    assert_equal "Unlocked", devices(:front_door).reload.state_label
    assert devices(:garage).apply(state: "open")
    assert_equal "Open", devices(:garage).reload.state_label
  end

  test "an unreachable device refuses the patch and keeps its state" do
    assert_not devices(:string_lights).apply(on: true)
    assert_not devices(:string_lights).reload.on?
  end

  test "lights summary: how many on, in how many rooms" do
    assert_equal 3, @household.lights_on.size
    assert_equal 3, @household.rooms_lit.size
    devices(:pendants).apply(on: false)
    assert_equal 2, @household.rooms_lit.size
  end

  test "security summary: locked, or what is open" do
    assert @household.secure?
    assert_equal "All locked", @household.security_line
    devices(:side_door).apply(locked: false)
    assert_not @household.secure?
    assert_equal "Side Door unlocked", @household.security_line
    devices(:garage).apply(state: "open")
    assert_equal "Garage open", @household.security_line
  end

  test "activating a scene applies its levels and can be reverted" do
    activation = scenes(:movie).activate!
    assert_not devices(:pendants).reload.on?
    assert_equal 15, devices(:floor_lamp).reload.level
    assert_equal 0, devices(:shade).reload.position
    assert_equal [ "pendants", "floor_lamp", "shade" ].map { |d| devices(d).id }.sort, activation.changed_device_ids.sort

    activation.revert!
    assert devices(:pendants).reload.on?
    assert_equal 80, devices(:pendants).level
    assert_equal 45, devices(:floor_lamp).reload.level
    assert_equal 60, devices(:shade).reload.position
  end

  test "a locks-all scene locks every door" do
    devices(:side_door).apply(locked: false)
    scenes(:goodnight).activate!
    assert devices(:side_door).reload.locked?
    assert_equal "All locked", @household.security_line
  end

  test "the thermostat steps by half a degree inside 15-28 and wakes from off into heat" do
    t = thermostats(:main)
    t.adjust!(0.5)
    assert_equal 22.0, t.reload.target_temperature
    t.update!(target_temperature: 28)
    t.adjust!(0.5)
    assert_equal 28.0, t.reload.target_temperature
    t.update!(mode: "off")
    t.adjust!(-0.5)
    assert_equal "heat", t.reload.mode
    assert_equal "Heating", t.verb
    t.update!(target_temperature: 20.5)
    assert_equal "Holding", t.verb
    t.update!(target_temperature: 19)
    assert_equal "Cooling", t.verb
    t.update!(mode: "off")
    assert_equal "Off", t.verb
    assert_equal "27.5", thermostats(:main).tap { |x| x.update!(target_temperature: 27.5) }.target_label
    assert_equal "28", thermostats(:main).tap { |x| x.update!(target_temperature: 28) }.target_label
  end
end
