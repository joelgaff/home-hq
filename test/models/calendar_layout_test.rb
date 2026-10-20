require "test_helper"

# Overlap layout (ui-spec §1.2): clusters of overlapping events get greedy columns, two at most;
# with three or more the first column stays and the rest collapse into one "+N more" block.
class CalendarLayoutTest < ActiveSupport::TestCase
  Slot = Struct.new(:title, :starts_at, :ends_at)

  def slot(title, from, to)
    Slot.new(title, Time.utc(2026, 10, 14, *from), Time.utc(2026, 10, 14, *to))
  end

  test "non-overlapping events take the full width" do
    items = CalendarLayout.place([ slot("A", [ 9 ], [ 10 ]), slot("B", [ 10 ], [ 11 ]) ])
    assert_equal [ [ 0, 1 ], [ 0, 1 ] ], items.map { |i| [ i.col, i.cols ] }
  end

  test "two overlapping events share the width" do
    items = CalendarLayout.place([ slot("A", [ 9 ], [ 10, 30 ]), slot("B", [ 10 ], [ 11 ]) ])
    assert_equal [ [ 0, 2 ], [ 1, 2 ] ], items.map { |i| [ i.col, i.cols ] }
  end

  test "three or more collapse everything after the first column into a more block" do
    a, b, c = slot("A", [ 9 ], [ 11 ]), slot("B", [ 9, 30 ], [ 10, 30 ]), slot("C", [ 10 ], [ 12 ])
    items = CalendarLayout.place([ a, b, c ])
    assert_equal 2, items.size
    assert_equal a, items.first.event
    assert_equal [ 0, 2 ], [ items.first.col, items.first.cols ]
    more = items.last
    assert more.more?
    assert_equal [ b, c ], more.events
    assert_equal Time.utc(2026, 10, 14, 9, 30), more.starts_at
    assert_equal Time.utc(2026, 10, 14, 12), more.ends_at
    assert_equal [ 1, 2 ], [ more.col, more.cols ]
  end

  test "a column frees up once its event ends" do
    items = CalendarLayout.place([ slot("A", [ 9 ], [ 10 ]), slot("B", [ 9, 30 ], [ 10, 30 ]), slot("C", [ 10 ], [ 11 ]) ])
    assert_equal [ [ 0, 2 ], [ 1, 2 ], [ 0, 2 ] ], items.map { |i| [ i.col, i.cols ] }
  end
end
