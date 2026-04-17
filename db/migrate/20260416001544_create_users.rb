class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username
      t.string :password_digest, null: false
      t.string :role

      t.timestamps
    end

    add_index :users, :username, unique: true
  end
end
