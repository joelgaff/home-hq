require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "colour, its rgb triplet and ink drive the person style" do
    assert_equal "45 91 255", people(:wes).rgb
    assert_equal "--c:#2D5BFF;--c-rgb:45 91 255;--c-ink:#FFFFFF", people(:wes).style
  end

  test "the family pseudo-person is black on white and shows a star" do
    family = households(:primary).family
    assert_equal "Family", family.name
    assert_equal "--c:#111111;--c-rgb:17 17 17;--c-ink:#FFFFFF", family.style
    assert family.family?
    assert_not people(:wes).family?
    assert_equal "★", family.initial
    assert_equal "W", people(:wes).initial
  end

  test "people are ordered by position" do
    assert_equal %w[Wes Claudia Buzzsaw Skidmark], households(:primary).people.map(&:name)
  end

  test "presence line: Home, ETA, or the status" do
    assert_equal "Home", people(:buzzsaw).presence_line
    assert_equal "ETA 12 min", people(:wes).presence_line
    assert_equal "At the office", people(:claudia).presence_line
  end

  test "a person needs a name and a colour" do
    person = households(:primary).people.new(name: "", color: "")
    assert_not person.valid?
    assert_includes person.errors.attribute_names, :name
    assert_includes person.errors.attribute_names, :color
  end
end
