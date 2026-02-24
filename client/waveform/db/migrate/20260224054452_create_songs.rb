class CreateSongs < ActiveRecord::Migration[8.1]
  def change
    create_table :songs do |t|
      t.string :name
      t.string :artist

      t.timestamps
    end
  end
end
