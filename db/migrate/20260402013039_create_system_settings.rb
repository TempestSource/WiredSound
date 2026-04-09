class CreateSystemSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :system_settings do |t|
      t.string :key
      t.string :value

      t.timestamps
    end
  end
end
