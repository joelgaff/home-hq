# A read-only calendar feed (plan: Calendars, pluggable sources). One adapter per kind (ICS is the
# only one today), all producing the same Event rows for a rolling window. Who an event is for:
# a manual override on the event, else names in its title, else this calendar's assigned people,
# else everyone.
class CalendarSource < ApplicationRecord
  include Audited
  WINDOW = (-7.days)..(60.days)
  ADAPTERS = { "ics" => "CalendarSources::Ics" }.freeze

  belongs_to :household
  has_many :calendar_source_people, dependent: :destroy
  has_many :people, through: :calendar_source_people
  has_many :events, dependent: :destroy

  validates :name, :url, presence: true
  audited "calendar_source", only: %w[name url enabled refresh_minutes]
  validates :kind, inclusion: ADAPTERS.keys
  validates :refresh_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  normalizes :url, with: ->(u) { u.to_s.strip.sub(/\Awebcal:/i, "https:") }

  validate :not_a_share_link

  scope :enabled, -> { where(enabled: true) }

  def adapter
    ADAPTERS.fetch(kind).constantize.new(self)
  end

  def due?(at: Time.current)
    enabled? && (synced_at.nil? || synced_at <= at - refresh_minutes.minutes)
  end

  # A feed is stale once it has missed a few syncs (plan: Offline and stale data); the screens say
  # so. "unreadable" when the last try failed and nothing good came since.
  def staleness(now = Current.now)
    limit = [ refresh_minutes * 3, 30 ].max.minutes
    late = synced_at.present? && synced_at < now - limit
    return :unreadable if last_error.present? && (synced_at.nil? || late)
    :late if late
  end

  def window(now = Current.now)
    (now + WINDOW.begin)..(now + WINDOW.end)
  end

  # Fetches (or takes) the feed, upserts its events for the window and removes the ones no longer
  # in it; people are assigned by the rules unless overridden by hand. A bad feed is recorded and
  # the last good events stay.
  def sync!(body: nil, now: Current.now)
    body ||= adapter.fetch
    rows = adapter.parse(body, window(now))
    transaction do
      kept = rows.map do |row|
        event = events.find_or_initialize_by(uid: row[:uid])
        event.household = household
        event.assign_attributes(row.except(:uid))
        event.save!
        assign_people(event) unless event.people_overridden?
        event.id
      end
      events.where.not(id: kept).destroy_all
    end
    update!(synced_at: now, last_error: nil)
    true
  rescue CalendarSources::Ics::NotFound => e
    message = google_public? ? "this Google calendar is not public; #{CalendarSources::Ics::SECRET_HINT}" : e.message
    update!(last_error: message.truncate(250))
    false
  rescue StandardError => e
    update!(last_error: e.message.truncate(250))
    false
  end

  # The rules: names in the title (in the order written, nicknames included), else this calendar's
  # people, else everyone (a family event).
  def people_for(title)
    household_people = household.people.to_a
    named = household_people.filter_map { |p| (i = p.named_at(title)) && [ i, p ] }.sort_by(&:first).map(&:last)
    return named if named.any?
    people.to_a.presence || household_people
  end

  def assign_people(event)
    event.set_people!(people_for(event.title))
  end

  private

  def google?
    URI.parse(url.to_s).host.to_s.casecmp?("calendar.google.com")
  rescue URI::InvalidURIError
    false
  end

  def google_public?
    google? && url.to_s.include?("/public/")
  end

  # A "share" or "add this calendar" link (…/calendar/u/0?cid=… or …/calendar/embed?src=…) is a
  # web page, not a feed.
  def not_a_share_link
    return unless google? && !url.to_s.include?("/calendar/ical/")
    errors.add(:url, "is a Google share link, not a feed; #{CalendarSources::Ics::SECRET_HINT}")
  end
end
