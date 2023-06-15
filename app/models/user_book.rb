# frozen_string_literal: true

class UserBook < ApplicationRecord
  acts_as_list
  belongs_to :user
  belongs_to :book

  READ = 'read'
  WANT_TO_READ = 'want_to_read'
  READING = 'reading'
  USER_BOOK_STATUSES = [WANT_TO_READ, READING, READ].freeze

  SLUGS_READABLE = {
    READ => 'Read',
    READING => 'Currently reading',
    WANT_TO_READ => 'Want to read'
  }.freeze

  validates :slug, inclusion: { in: USER_BOOK_STATUSES.map(&:to_s), message: "%<value>s must be one of #{USER_BOOK_STATUSES.map(&:to_s)}" }
end
