# Declares which dashboard pieces a model's changes move (Pieces). `syncs_pieces :chores,
# :"today-chores"` broadcasts those ids after every commit; a block picks the household when it
# is not `household` on the record.
module SyncsPieces
  extend ActiveSupport::Concern

  class_methods do
    def syncs_pieces(*ids, household: :household, if: nil)
      condition = binding.local_variable_get(:if)
      after_commit do
        next if condition && !instance_exec(&condition)
        target = household.is_a?(Proc) ? instance_exec(&household) : send(household)
        Pieces.changed(target, ids) if target
      end
    end
  end
end
