require "test_helper"

# Chores on a phone (the approved mockup): the lanes stack as cards behind a row of person chips
# (kids first, with their stars) that narrows the view to one person.
class ChoresPhoneTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.utc(2026, 10, 14, 15, 18) }

  test "a person's page has the person chips, kids first with stars, then Anyone" do
    sign_in_as users(:owner)
    get chores_path
    assert_select ".tasks[data-controller~=picker]", 1
    assert_select ".ch-chips button[data-pick]" do |chips|
      assert_equal %w[Buzzsaw Skidmark Wes Claudia Anyone], chips.map { |c| c.css("b").text }
    end
    assert_select ".ch-chips button[data-pick=#{people(:buzzsaw).id}] .num", people(:buzzsaw).stars.to_s
    assert_select ".ch-chips button[data-pick=any]", 1
    assert_select ".ch-lanes .ch-lane[data-lane=#{people(:buzzsaw).id}].is-kid", 1
  end

  test "the frame has no chips" do
    show_on_screen
    get chores_path
    assert_select ".ch-chips", 0
    assert_select ".ch-lanes .ch-lane", 5
  end
end
