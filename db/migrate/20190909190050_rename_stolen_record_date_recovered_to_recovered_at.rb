class RenameStolenRecordDateRecoveredToRecoveredAt < ActiveRecord::Migration
  def change
    rename_column :stolen_records, :date_recovered, :recovered_at
  end
end
