# Places a day's timed events side by side when they overlap (ui-spec §1.2 "Overlap"): events
# are clustered, each cluster gets greedy columns, at most two; with three or more columns the
# first stays and everything else collapses into one "+N more" block.
class CalendarLayout
  Item = Struct.new(:event, :col, :cols, keyword_init: true) do
    def more? = false
  end

  More = Struct.new(:events, :starts_at, :ends_at, :col, :cols, keyword_init: true) do
    def more? = true
  end

  def self.place(events)
    new(events).items
  end

  def initialize(events)
    @events = events.sort_by { |e| [ e.starts_at, -e.ends_at.to_i ] }
  end

  def items
    clusters.flat_map { |cluster| place_cluster(cluster) }
  end

  private

  def clusters
    out, current, current_end = [], nil, nil
    @events.each do |e|
      if current.nil? || e.starts_at >= current_end
        current = []
        out << current
        current_end = e.ends_at
      end
      current << e
      current_end = [ current_end, e.ends_at ].max
    end
    out
  end

  def place_cluster(cluster)
    column_ends, placed = [], []
    cluster.each do |e|
      col = column_ends.index { |ends| ends <= e.starts_at } || column_ends.size
      column_ends[col] = e.ends_at
      placed << [ e, col ]
    end
    cols = column_ends.size
    return placed.map { |e, col| Item.new(event: e, col: col, cols: cols) } if cols <= 2

    extra = placed.select { |_, col| col > 0 }.map(&:first)
    placed.select { |_, col| col.zero? }.map { |e, _| Item.new(event: e, col: 0, cols: 2) } +
      [ More.new(events: extra, starts_at: extra.map(&:starts_at).min, ends_at: extra.map(&:ends_at).max, col: 1, cols: 2) ]
  end
end
