# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :validatable, :registerable

  has_many :reviews, dependent: :destroy

  def name
    email.split('@').first.capitalize
  end
end
