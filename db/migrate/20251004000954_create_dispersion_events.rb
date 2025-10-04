class CreateDispersionEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :dispersion_events do |t|
      t.references :chemical, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.decimal :release_rate
      t.decimal :release_volume
      t.decimal :release_mass
      t.decimal :release_duration
      t.string :release_type
      t.datetime :started_at
      t.datetime :ended_at
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
