# frozen_string_literal: true

API_KEY ||= ENV["GOOGLE_BOOKS_API_KEY"]

class GoogleBooksSearch
  class Unavailable < StandardError; end

  TTL = 7.days
  MAX = 10
  TIMEOUT = 10

  def self.call(raw_query, count: MAX, raise_on_error: false)
    query = normalize(raw_query)
    return [] if query.blank?

    key = cache_key(query, count)

    Rails.cache.fetch(key, expires_in: TTL) do
      # IMPORTANT: only do the external call inside the cache block
      fetch_books(query, count)
    end
  rescue StandardError => e
    Rails.logger.warn("[GoogleBooksSearch] failed: #{e.class} #{e.message}")
    raise Unavailable, 'Google Books search is unavailable.' if raise_on_error

    []
  end

  def self.fetch_books(query, count)
    uri = URI::HTTPS.build(
      host: 'www.googleapis.com', path: '/books/v1/volumes',
      query: URI.encode_www_form({ q: query, maxResults: count, key: API_KEY.presence }.compact)
    )
    response = GoogleBooks.get(uri.to_s, timeout: TIMEOUT)
    payload = response.parsed_response
    # The gem turns HTTP error payloads into an empty list; check the response first.
    valid = response.code == 200 && payload.is_a?(Hash) && payload['totalItems'].is_a?(Integer)
    raise Unavailable, 'Google Books returned an invalid response.' unless valid

    GoogleBooks::Response.new(payload).to_a
  end

  def self.normalize(q)
    q.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def self.cache_key(query, count)
    digest = Digest::SHA256.hexdigest(query)
    "gbooks:search:v2:q=#{digest}:count=#{count}"
  end

  private_class_method :fetch_books, :normalize, :cache_key
end
