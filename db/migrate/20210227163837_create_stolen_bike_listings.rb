class CreateStolenBikeListings < ActiveRecord::Migration[5.2]
  def change
    create_table :stolen_bike_listings do |t|
      t.references :bike
      t.references :initial_listing
      t.references :primary_frame_color
      t.references :secondary_frame_color
      t.references :tertiary_frame_color

      # Manufacturer
      t.references :manufacturer
      t.string :manufacturer_other

      t.text :frame_model

      # stolen bike listing specific
      t.datetime :listed_at
      t.integer :amount_cents
      t.string :currency
      t.text :listing_text
      t.jsonb :data

      t.timestamps
    end
  end
end
