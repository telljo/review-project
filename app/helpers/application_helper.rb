# frozen_string_literal: true

# Application helper
module ApplicationHelper
  def render_turbo_stream_flash_messages
    turbo_stream.prepend 'flash', partial: 'layouts/flash'
  end

  def search_result_actions_dom_id(isbn)
    normalized = isbn.to_s.gsub(/[^0-9A-Za-z]/, "").downcase
    "search-result-actions-#{normalized}"
  end
end
