# "Everyone": the black-on-white style used for events the whole household attends (ui-spec §1.2).
# Not a record; `household.family` builds it.
class Family
  include Styled

  attr_reader :household

  def initialize(household)
    @household = household
  end

  def name = "Family"
  def color = "#111111"
  def ink = "#FFFFFF"
  def initial = "★"
  def family? = true
  def kid? = false
  def id = "family"
end
