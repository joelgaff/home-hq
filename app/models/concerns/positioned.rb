# Up/down ordering for the settings lists (people, routines, chores within a lane, stores,
# categories, a store's aisle). `position` is renumbered 1..n within the list before a swap, so
# gaps and ties from seeds never matter.
module Positioned
  extend ActiveSupport::Concern

  # `siblings`: the ordered relation this record moves within (it must include the record).
  def move!(direction, siblings)
    list = siblings.to_a
    index = list.index { |r| r.id == id } or return
    other = direction.to_s == "up" ? index - 1 : index + 1
    return if other.negative? || other >= list.size
    list[index], list[other] = list[other], list[index]
    self.class.transaction { list.each_with_index { |r, i| r.update_column(:position, i + 1) } }
  end

  # Appends at the end of the list when nothing says otherwise.
  def place_last(siblings)
    self.position = (siblings.maximum(:position) || 0) + 1 if position.to_i.zero?
  end
end
