# The Shopping view's client state travels with every request as params: the store filter and
# whether the "Got it" drawer is open, so a write can re-render the list the same way.
module ShoppingContext
  extend ActiveSupport::Concern

  included do
    before_action :set_shopping_context
    helper_method :shopping_context
  end

  private

  def set_shopping_context
    @household = Current.household
    @store = @household.stores.find_by(id: params[:store])
    @drawer = params[:drawer].present? && params[:drawer] != "0"
  end

  def shopping_context
    { store: @store&.id, drawer: (@drawer ? 1 : nil) }.compact
  end
end
