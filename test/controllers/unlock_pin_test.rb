require "test_helper"

# Unlocking needs an adult (plan: gap review): on the frame, hold-to-unlock asks for an adult's
# PIN before the lock or garage moves; a signed-in adult on a phone needs none; a kid's login
# cannot unlock at all. Anyone can lock.
class UnlockPinTest < ActionDispatch::IntegrationTest
  setup do
    @lock = devices(:front_door)
    @lock.deviceable.update!(locked: true)
    people(:wes).update!(pin: "2468")
  end

  test "an adult sets a PIN of four to eight digits in Settings, and it is never shown back" do
    sign_in_as users(:owner)
    get edit_settings_person_path(people(:claudia))
    assert_select "input[name='person[pin]'][type=password]", 1
    assert_select "input[name='person[pin]'][value]", 0
    patch settings_person_path(people(:claudia)), params: { person: { pin: "13579" } }
    assert people(:claudia).reload.authenticate_pin("13579")
    assert_not people(:claudia).authenticate_pin("00000")
    patch settings_person_path(people(:claudia)), params: { person: { pin: "" } }
    assert people(:claudia).reload.authenticate_pin("13579"), "a blank PIN field keeps the PIN"
    patch settings_person_path(people(:claudia)), params: { person: { pin: "12" } }
    assert_response :unprocessable_entity
    patch settings_person_path(people(:buzzsaw)), params: { person: { pin: "1234" } }
    assert_response :unprocessable_entity, "kids have no PIN"
  end

  test "the frame is asked for a PIN before a lock opens; the right PIN opens it, a wrong one does not" do
    show_on_screen
    patch device_path(@lock), params: { locked: false }, as: :turbo_stream
    assert_response :success
    assert @lock.reload.locked?, "nothing moved yet"
    assert_select "turbo-stream[action=replace][target=sheet] .pin-pad", 1
    assert_select "turbo-stream[target=sheet] form[action=?] input[name=locked][value=false]", device_path(@lock), 1

    patch device_path(@lock), params: { locked: false, pin: "0000" }, as: :turbo_stream
    assert @lock.reload.locked?
    assert_select "turbo-stream[target=sheet] .pin-pad .pin-error", text: /not an adult's PIN/i

    patch device_path(@lock), params: { locked: false, pin: "2468" }, as: :turbo_stream
    assert_not @lock.reload.locked?
    assert_select "turbo-stream[action=replace][target=sheet]", 0
    assert_select "turbo-stream[target=toasts]", text: /unlocked/i

    patch device_path(@lock), params: { locked: true }, as: :turbo_stream
    assert @lock.reload.locked?, "anyone can lock, no PIN"
  end

  test "the garage asks for the PIN too, only when opening" do
    garage = devices(:garage)
    garage.deviceable.update!(state: "closed")
    show_on_screen
    patch device_path(garage), params: { state: "opening" }, as: :turbo_stream
    assert_equal "closed", garage.reload.state
    assert_select "turbo-stream[target=sheet] .pin-pad", 1
    patch device_path(garage), params: { state: "opening", pin: "2468" }, as: :turbo_stream
    assert_equal "opening", garage.reload.state
    garage.deviceable.update!(state: "open")
    patch device_path(garage), params: { state: "closing" }, as: :turbo_stream
    assert_equal "closing", garage.reload.state, "closing needs no PIN"
  end

  test "an adult on a phone unlocks without a PIN; a kid cannot unlock" do
    sign_in_as users(:owner)
    patch device_path(@lock), params: { locked: false }, as: :turbo_stream
    assert_not @lock.reload.locked?

    @lock.deviceable.update!(locked: true)
    people(:buzzsaw).update!(email: "kid@example.com")
    kid = Identity.create!(email: "kid@example.com")
    kid_user = households(:primary).users.create!(identity: kid)
    people(:buzzsaw).update!(user: kid_user)
    reset!
    sign_in_as kid_user
    patch device_path(@lock), params: { locked: false }, as: :turbo_stream
    assert @lock.reload.locked?
    assert_select "turbo-stream[target=toasts]", text: /adult/i
  end
end
