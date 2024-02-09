# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :validatable, :registerable, :rememberable

  has_many :reviews, dependent: :destroy
  has_many :user_books, dependent: :destroy
  has_many :books, through: :user_books

  validates :email, uniqueness: true
  validates :username, presence: true, uniqueness: true

  def name
    email.split('@').first.capitalize
  end

  def to_param
    username
  end
end
