# A calendar assigned to a person (none assigned = the whole family).
class CalendarSourcePerson < ApplicationRecord
  belongs_to :calendar_source
  belongs_to :person
end
