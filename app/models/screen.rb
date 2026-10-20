# A display device (the wall frame) that shows the dashboard. It signs in once by opening its
# enrollment link, then stays signed in through a long-lived cookie holding its session token.
# Each screen has its own settings (plan: per-screen settings): night hours, the view it starts on
# and idles back to, and the hour it reloads itself to keep the old WebView healthy.
class Screen < ApplicationRecord
  include Audited

  VIEWS = {
    "home" => "Today", "calendar" => "Calendar", "tasks" => "Chores", "shopping" => "Shopping",
    "photos" => "Photos", "control" => "Home", "people" => "People"
  }.freeze
  # At night the screen goes dark (the gap review's default; a tap wakes it) or shows Wes's red clock.
  NIGHT_STYLES = { "off" => "Screen off (dark; a tap wakes it)", "clock" => "Red night clock" }.freeze
  # Settings the page bakes in: the screen reloads when they change (the household's do the same).
  RELOAD_SETTINGS = %w[night_from night_to night_style default_view reload_hour].freeze

  belongs_to :household

  has_secure_token :enrollment_token

  validates :name, presence: true
  audited "screen", only: %w[name night_from night_to night_style default_view reload_hour]
  validates :default_view, inclusion: VIEWS.keys
  validates :night_style, inclusion: NIGHT_STYLES.keys
  validates :night_from, :night_to, numericality: { only_integer: true, in: 0..23 }
  validates :reload_hour, numericality: { only_integer: true, in: 0..23 }, allow_nil: true
  after_update_commit :reload_page, if: -> { RELOAD_SETTINGS.any? { |name| saved_change_to_attribute?(name) } }

  scope :enrollable, -> { where.not(enrollment_token: nil) }

  def enrolled?
    enrolled_at.present?
  end

  def enroll!
    update!(enrollment_token: nil, session_token: self.class.generate_unique_secure_token, enrolled_at: Time.current)
  end

  # ---------------------------------------------------------------- settings
  # Night runs from night_from up to night_to, through midnight when needed; equal hours = never.
  def night?(hour)
    return false if night_from == night_to
    night_from < night_to ? (hour >= night_from && hour < night_to) : (hour >= night_from || hour < night_to)
  end

  def night_hours_label
    night_from == night_to ? "Never" : "#{self.class.hour_word(night_from)} – #{self.class.hour_word(night_to)}"
  end

  # "10 PM – 6 AM, screen off"
  def night_label
    return "Never" if night_from == night_to
    "#{night_hours_label}, #{night_style == 'off' ? 'screen off' : 'red clock'}"
  end

  def default_view_name
    VIEWS[default_view]
  end

  def self.hour_word(h)
    "#{h % 12 == 0 ? 12 : h % 12} #{h < 12 ? 'AM' : 'PM'}"
  end

  def self.hour_options
    (0..23).map { |h| [ hour_word(h), h ] }
  end

  private

  def reload_page
    Turbo::StreamsChannel.broadcast_action_to(self, action: "reload")
  end
end
