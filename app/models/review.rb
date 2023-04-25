# frozen_string_literal: true

class Review < ApplicationRecord
  belongs_to :user
  belongs_to :book
  has_rich_text :content
  has_one_attached :image

  validates_presence_of :content

  MAX_RATING = 5

  validates :rating, numericality: { only_integer: true, in: 0..MAX_RATING }

  scope :ordered, -> { order(id: :desc) }

  broadcasts_to ->(review) { [review.user, 'reviews'] }, inserts_by: :prepend
end
