# frozen_string_literal: true

class Book < ApplicationRecord
  has_many :users, through: :user_books
  has_many :user_books, dependent: :destroy
  has_many :reviews

  validates :title, presence: true
  validates :author, presence: true

  scope :ordered, -> { order(id: :desc) }

  def average_review_score
    reviews.average(:rating)
  end
end
