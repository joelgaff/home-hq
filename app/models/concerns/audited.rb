# Settings records that write the audit log on create, update and destroy (plan: milestone 5).
# `audited "person", only: %w[name ...]` logs an update only when one of those attributes changed
# (so a presence change by the hub is not a "settings change").
module Audited
  extend ActiveSupport::Concern

  class_methods do
    def audited(kind, only: nil, household: :household)
      after_create { audit_record("#{kind}.created", household) }
      after_update do
        changes = saved_changes.except("updated_at", "created_at", "position")
        changes = changes.slice(*only) if only
        audit_record("#{kind}.updated", household, details: { "changes" => changes.transform_values { |(from, to)| [ from, to ].map { |v| v.is_a?(String) && v.length > 60 ? "#{v[0, 60]}…" : v } } }) if changes.any?
      end
      after_destroy { audit_record("#{kind}.removed", household) }
    end
  end

  private

  def audit_record(action, household_method, details: {})
    target = household_method.is_a?(Proc) ? instance_exec(&household_method) : send(household_method)
    AuditEntry.record(action, household: target, subject: destroyed? ? nil : self, subject_name: try(:name) || try(:title), details: details) if target
  end
end
