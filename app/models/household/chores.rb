# Routines and chores (ui-spec §1.3): which routine is on now, a lane's chores, progress.
module Household::Chores
  extend ActiveSupport::Concern

  included do
    has_many :routines, -> { in_order }, dependent: :destroy
    has_many :chores, dependent: :destroy
    has_many :todos, dependent: :destroy
  end

  # A person's (or Anyone's, nil) to-dos for today (plan: People view): timed ones today in time
  # order, then open ones due today, overdue or undated, then the ones done today.
  def todos_today_for(person, today = Current.now.to_date)
    list = todos.for_person(person).includes(:person).select do |t|
      next t.due_at.in_time_zone.to_date == today if t.timed?
      next t.done_at.in_time_zone.to_date == today if t.done?
      t.due_on.nil? || t.due_on <= today
    end
    list.sort_by do |t|
      if t.timed? then [ 0, t.due_at.to_i ]
      elsif !t.done? then [ 1, t.due_on ? t.due_on.jd : 9_999_999, t.id ]
      else [ 2, t.done_at.to_i ]
      end
    end
  end

  # The open to-dos a Today lane shows: timed ones today, and the "To do" group (untimed due
  # today, overdue, or undated).
  def open_todos_for(person, today = Current.now.to_date)
    todos_today_for(person, today).reject(&:done?)
  end

  # The routines that run on a day (weekend-only ones stay out on weekdays).
  def active_routines(on: Current.now.to_date)
    routines.select { |r| r.active_on?(on) }
  end

  def current_routine(at: Current.now)
    active = active_routines(on: at.to_date)
    active.find { |r| r.covers?(at.hour) } || active.last || routines.last
  end

  # The vacation pause (plan: Simplifications): nothing is due through the date.
  def chores_paused?(date = Current.now.to_date)
    chores_paused_until.present? && date <= chores_paused_until
  end

  # One lane's chores today: the routine's own that are due, plus, in the current routine, the
  # overdue ones carried over from earlier routines. Not-done first, overdue first.
  def chores_for(routine, person:, at: Current.now)
    chores_today_for(routine, at: at).select { |c| c.person_id == person&.id }.sort_by(&:sort_key)
  end

  # [done, total] for the routine today, carried overdue chores included.
  def routine_progress(routine, at: Current.now)
    list = chores_today_for(routine, at: at)
    [ list.count(&:done?), list.size ]
  end

  # Every chore with its routine and today's completions, loaded once per request: the lanes, the
  # rings, the progress and the week strips all read from it. Chore and completion writes clear it
  # (Current.chores_cache), so a write's own re-render sees itself.
  def loaded_chores
    cache = (Current.chores_cache ||= {})
    cache[id] ||= chores.includes(:routine, :completions_today).in_order.to_a
  end

  private

  def chores_today_for(routine, at:)
    date = at.to_date
    all = loaded_chores
    own = all.select { |c| c.routine_id == routine.id && c.due_on?(date) }
    return own unless routine == current_routine(at: at)
    own + all.select { |c| c.routine_id != routine.id && c.overdue?(at: at) }
  end
end
