# The People view (plan: People view): the avatars, or one person's page, as the "people" Turbo
# Frame so a tap never leaves the page.
class PeopleController < ApplicationController
  def show
    @household = Current.household
    render partial: "people/people", locals: { person: @household.people.find_by(id: params[:person]) }, layout: false
  end
end
