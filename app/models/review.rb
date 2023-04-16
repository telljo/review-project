# frozen_string_literal: true

class Review < ApplicationRecord
  validates :name, presence: true
  belongs_to :user
  # belongs_to :book
  has_rich_text :content
  has_one_attached :image

  validates_presence_of :name
  validates_presence_of :content

  scope :ordered, -> { order(id: :desc) }

  broadcasts_to ->(review) { [review.user, 'reviews'] }, inserts_by: :prepend
end
