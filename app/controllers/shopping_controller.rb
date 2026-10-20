# The Shopping view's list (ui-spec §1.4): one store filter (or all) and the Got it drawer.
class ShoppingController < ApplicationController
  include ShoppingContext

  def show
    render partial: "shopping/list", locals: { store: @store, drawer: @drawer }, layout: false
  end
end
