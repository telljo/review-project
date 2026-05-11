# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'nokogiri'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

module RequestSpecHelpers
  def parsed_body
    Nokogiri::HTML5(response.body)
  end

  def css_texts(selector)
    parsed_body.css(selector).map { |node| node.text.squish }
  end

  def create_user(email:, username:)
    User.create!(
      email:,
      username:,
      password: 'password',
      password_confirmation: 'password'
    )
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password'
      }
    }
  end
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true

  config.define_derived_metadata(file_path: %r{/spec/requests/}) do |metadata|
    metadata[:type] = :request
  end

  config.include RequestSpecHelpers, type: :request

  config.filter_rails_from_backtrace!
end
