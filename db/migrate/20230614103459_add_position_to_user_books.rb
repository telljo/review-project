# frozen_string_literal: true

class AddPositionToUserBooks < ActiveRecord::Migration[7.0]
  def change
    add_column :user_books, :position, :integer
  end
end
