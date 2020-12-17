class CreateImpoundClaims < ActiveRecord::Migration[5.2]
  def change
    create_table :impound_claims do |t|
      t.references :impound_record, index: true
      t.references :stolen_record, index: true
      t.references :user, index: true

      t.text :message

      t.integer :status
      t.datetime :submitted_at
      t.datetime :resolved_at

      t.timestamps
    end
  end
end
