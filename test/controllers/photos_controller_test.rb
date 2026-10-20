require "test_helper"

# The Photos view (docs/ui-spec.md §1.5): full-bleed slideshow with layout modes and favourites.
class PhotosControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:owner) }

  test "the dashboard page carries the photos view with its slideshow, zones and controls" do
    get root_path
    assert_select "#view-photos.view--bleed .photos" do
      assert_select ".ph-stage[data-controller=slideshow][data-slideshow-interval-value='15000'][data-slideshow-layout-value=auto]"
      assert_select ".ph-zone--l[data-action*='photos#prev']"
      assert_select ".ph-zone--c[data-action*='photos#loud']"
      assert_select ".ph-zone--r[data-action*='photos#next']"
      assert_select ".ph-top .seg button[data-layout]", 5
      assert_select ".ph-top .seg button[data-layout=auto].is-on", 1
      assert_select ".ph-bottom .ph-btn--fav span", "Favourite"
    end
  end

  test "favouriting a photo toggles it and says it will show up more often" do
    patch photo_path(photos(:tofino)), params: { favorite: true }, as: :turbo_stream
    assert photos(:tofino).reload.favorite?
    assert_select "turbo-stream[target=toasts] .toast-msg", /Added to favourites · it’ll show up more often/
    patch photo_path(photos(:tofino)), params: { favorite: false }, as: :turbo_stream
    assert_not photos(:tofino).reload.favorite?
    assert_select "turbo-stream[target=toasts] .toast-msg", "Removed from favourites"
  end
end
