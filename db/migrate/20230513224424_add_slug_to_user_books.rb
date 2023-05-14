# frozen_string_literal: true

class AddSlugToUserBooks < ActiveRecord::Migration[7.0]
  def change
    add_column :user_books, :slug, :string
    add_index :user_books, :slug
  end
end
