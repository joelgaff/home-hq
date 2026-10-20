# A member of the household: a lane on the calendar and chores views, a presence line on Today.
# Colours are per person everywhere (plan: calendars decision); `style` is the inline CSS custom
# properties Wes's stylesheets expect.
class Person < ApplicationRecord
  include Audited
  include Styled
  include Positioned
  include SyncsPieces

  belongs_to :household
  # Set from the person's email: the login with that address, linked when either side appears.
  belongs_to :user, optional: true
  has_many :attendees, dependent: :destroy
  has_many :events, through: :attendees
  has_many :chores, dependent: :nullify
  has_many :star_entries, dependent: :destroy
  has_many :photos, dependent: :nullify

  # An adult's PIN for unlocking from the frame (plan: gap review): 4 to 8 digits, kids none.
  has_secure_password :pin, validations: false
  validate :pin_rules, if: -> { pin.present? }

  validates :name, :color, presence: true
  validates :color, format: { with: /\A#\h{6}\z/, message: "must be a 6-digit hex colour" }
  # The email is the login (plan: Decisions, sign-in): an adult's gets Settings, a kid's the app.
  normalizes :email, with: ->(e) { e.to_s.strip.downcase.presence }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :household_id }, allow_nil: true
  before_save :link_login
  after_destroy { user&.destroy }
  after_commit :send_where_to_sign_in, if: -> { email.present? && saved_change_to_email? }
  before_validation :pick_ink, if: -> { ink.blank? || will_save_change_to_color? }
  before_validation { place_last(household.people) if household }
  syncs_pieces :"today-presence", :"today-lanes", :"today-agenda", :"today-chores", :chores
  audited "person", only: %w[name color kid email nicknames presence_entity pin_digest]

  scope :in_order, -> { order(:position, :id) }
  scope :kids, -> { where(kid: true) }

  def family? = false

  def pin? = pin_digest.present?

  def pin_rules
    errors.add(:pin, "is for adults") if kid?
    errors.add(:pin, "must be 4 to 8 digits") unless pin.match?(/\A\d{4,8}\z/)
  end

  # Where this person is named in an event title ("Skid karate", "Buzzsaw + Skidmark swim"):
  # whole-word, case-insensitive, on the name or any nickname; nil when absent.
  def named_at(title)
    [ name, *nicknames.to_s.split(",") ].map(&:strip).reject(&:blank?).filter_map do |n|
      title =~ /(?<![[:alnum:]])#{Regexp.escape(n)}(?![[:alnum:]])/i
    end.min
  end

  # The login with this email, if someone has signed in with it already (else it links at their
  # first sign-in); no email, no login.
  def link_login
    self.user = email.present? ? household.users.joins(:identity).find_by(identities: { email: email }) : nil
  end

  def send_where_to_sign_in
    LoginMailer.added(self).deliver_later
  end

  # Text on the person's colour: dark on light colours, white otherwise (Wes's ink values).
  def pick_ink
    self.ink = Styled.light?(color) ? "#111111" : "#FFFFFF"
  end

  def initial
    name.first
  end

  # Today's presence card: "Home", "ETA N min" or whatever the status says (ui-spec §1.1).
  def presence_line
    return "Home" if home?
    return "ETA #{eta_minutes} min" if eta_minutes.present?
    status.to_s
  end

  def eta?
    !home? && eta_minutes.present?
  end

  # ---------------------------------------------------------------- chores + stars (ui-spec §1.3)
  def stars
    star_entries.sum(:amount)
  end

  # The current week (from the household's first day): "hit" when every chore of theirs due that
  # day was done, "miss" otherwise, "off" when nothing was due (a pause, a rest day, no chores),
  # with today and the future set apart. [["M", "hit"], ...]
  def week_strip
    today = Current.now.to_date
    first = household.beginning_of_week(today)
    mine = household.loaded_chores.select { |c| c.person_id == id }
    done = ChoreCompletion.where(chore_id: mine.map(&:id), completed_on: first..today).pluck(:chore_id, :completed_on).to_set
    household.week_day_letters.each_with_index.map do |letter, i|
      day = first + i
      due = mine.select { |c| c.due_on?(day) }
      state = if day > today then "future"
      elsif day == today then "today"
      elsif due.empty? then "off"
      elsif due.all? { |c| done.include?([ c.id, day ]) } then "hit"
      else "miss"
      end
      [ letter, state ]
    end
  end
end
