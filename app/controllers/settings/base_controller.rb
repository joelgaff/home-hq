# The settings lists (plan: milestone 3): one controller per thing the household configures,
# each a plain CRUD with up/down ordering. Adults only; screens are refused.
class Settings::BaseController < ApplicationController
  before_action :require_adult
  before_action { @household = Current.household }
  layout "application"

  private

  def saved(path, notice = "Saved.")
    redirect_to path, notice: notice
  end
end
