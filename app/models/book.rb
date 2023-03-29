# frozen_string_literal: true

class Book < ApplicationRecord
  has_many :reviews
  has_many :users, through: :user_books
  has_many :user_books, dependent: :destroy

  validates :title, presence: true
  validates :author, presence: true

  scope :ordered, -> { order(id: :desc) }
end
