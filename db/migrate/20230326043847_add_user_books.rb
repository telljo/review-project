# frozen_string_literal: true

class AddUserBooks < ActiveRecord::Migration[7.0]
  def change
    create_table :user_books do |t|
      t.integer     :book_id, null: false
      t.integer     :user_id, null: false
      t.timestamps
    end

    add_index :user_books, :user_id
    add_index :user_books, :book_id
  end
end
