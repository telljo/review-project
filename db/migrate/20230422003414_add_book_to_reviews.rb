# frozen_string_literal: true

class AddBookToReviews < ActiveRecord::Migration[7.0]
  def change
    add_reference :reviews, :book, index: true
  end
end
