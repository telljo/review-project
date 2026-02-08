# frozen_string_literal: true

API_KEY = ENV["GOOGLE_BOOKS_API_KEY"]

class GoogleBooksSearch
  TTL = 7.days
  MAX = 10

  def self.call(raw_query, count: MAX)
    query = normalize(raw_query)
    return [] if query.blank?

    key = cache_key(query, count)

    Rails.cache.fetch(key, expires_in: TTL) do
      # IMPORTANT: only do the external call inside the cache block
      GoogleBooks.search(query, count: count, api_key: API_KEY).to_a
    end
  rescue StandardError => e
    Rails.logger.warn("[GoogleBooksSearch] failed: #{e.class} #{e.message}")
    []
  end

  def self.normalize(q)
    q.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def self.cache_key(query, count)
    digest = Digest::SHA256.hexdigest(query)
    "gbooks:search:v1:q=#{digest}:count=#{count}"
  end

  private_class_method :normalize, :cache_key
end
