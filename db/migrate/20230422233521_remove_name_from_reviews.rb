# frozen_string_literal: true

class RemoveNameFromReviews < ActiveRecord::Migration[7.0]
  def change
    remove_column :reviews, :name
    add_column :reviews, :rating, :integer, index: true
  end
end
