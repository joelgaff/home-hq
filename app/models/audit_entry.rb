# The audit log (plan: second gap review; milestone 5): settings changes, chore completions and
# unlocks, with who did it. The actor is the PIN's adult, the login's person, the login, or the
# screen; names are copied so entries outlive what they name. Pruned after ninety days.
class AuditEntry < ApplicationRecord
  KEEP = 90.days

  belongs_to :household
  belongs_to :actor, polymorphic: true, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.record(action, household:, subject: nil, subject_name: nil, details: {})
    actor = Current.pin_person || Current.user&.person || (Current.user && household.member_for(Current.user)) || Current.user || Current.screen
    household.audit_entries.create!(action: action, actor: actor, actor_name: actor_label(actor), subject: subject,
      subject_name: subject_name || subject.try(:name) || subject.try(:title), details: details)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn "Audit entry #{action} not written: #{e.message}"
    nil
  end

  def self.actor_label(actor)
    case actor
    when Person, Screen then actor.name
    when User then actor.email
    else "System"
    end
  end

  def self.prune!(before: KEEP.ago)
    where(created_at: ...before).delete_all
  end

  # "Wes unlocked Front Door", "Kitchen completed Homework", "Wes changed the household (name)".
  def sentence
    who = actor_name.presence || "Someone"
    what = subject_name.to_s
    changed = details["changes"].is_a?(Hash) ? " (#{details['changes'].keys.map { |k| k.tr('_', ' ') }.join(', ')})" : ""
    kind, verb = action.split(".", 2)
    case action
    when "chore.completed" then "#{who} completed #{what}#{details['for'] ? " for #{details['for']}" : ''}"
    when "chore.undone" then "#{who} undid #{what}"
    when "todo.completed" then "#{who} ticked off #{what}"
    when "device.unlocked" then "#{who} unlocked #{what}"
    when "device.locked" then "#{who} locked #{what}"
    when "device.garage_opened" then "#{who} opened the garage"
    when "scene.activated" then "#{who} turned on the #{what} scene"
    when "lights.off" then "#{who} turned everything off"
    when "alert.acknowledged" then "#{who} acknowledged the #{what} alert"
    when "device.relocked" then "#{what} relocked itself"
    when "valve.closed" then "#{who} shut off the water main"
    when "locks.all" then "#{who} locked all doors"
    when "grocery.updated" then "#{who} changed #{what} on the shopping list#{changed}"
    when "grocery.removed" then "#{who} removed #{what} from the shopping list"
    when "household.updated" then "#{who} changed the household#{changed}"
    else
      noun = { "calendar_source" => "the #{what} calendar", "screen" => "the #{what} screen" }.fetch(kind, what)
      case verb
      when "created" then "#{who} added #{noun}"
      when "updated" then "#{who} changed #{noun}#{changed}"
      when "removed" then "#{who} removed #{noun}"
      else "#{who} #{verb} #{noun}"
      end
    end
  end
end
