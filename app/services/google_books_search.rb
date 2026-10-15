# frozen_string_literal: true

API_KEY ||= ENV["GOOGLE_BOOKS_API_KEY"]

class GoogleBooksSearch
  class Unavailable < StandardError
    attr_reader :reason, :retry_at

    def initialize(reason: :unavailable, retry_at: nil)
      @reason = reason
      @retry_at = retry_at
      messages = { timeout: 'Google Books took too long to respond.',
                   rate_limited: 'Google Books is receiving too many searches right now.' }
      super(messages.fetch(reason, 'Google Books is temporarily unavailable.'))
    end

    def retry_after
      retry_at ? [(retry_at - Time.current).ceil, 0].max : 0
    end
  end

  TTL = 7.days
  MAX = 10
  TIMEOUT = 10
  DEFAULT_RETRY_WAIT = 30

  def self.call(raw_query, count: MAX, raise_on_error: false)
    query = normalize(raw_query)
    return [] if query.blank?

    key = cache_key(query, count)

    cached = read_cache(key)
    return cached if cached.is_a?(Array)

    retry_at = read_cache(cooldown_key)
    raise Unavailable.new(reason: :rate_limited, retry_at: retry_at) if retry_at.is_a?(Time) && retry_at > Time.current

    books = fetch_books(query, count)
    write_cache(key, books, TTL)
    books
  rescue StandardError => e
    failure = failure_for(e)
    # Request exception messages can contain the API key or the reader's query.
    Rails.logger.warn("[GoogleBooksSearch] failed: #{e.class} (#{failure.reason})")
    raise failure if raise_on_error

    []
  end

  def self.failure_for(error)
    return error if error.is_a?(Unavailable)

    Unavailable.new(reason: error.is_a?(Timeout::Error) ? :timeout : :unavailable)
  end

  def self.fetch_books(query, count)
    uri = URI::HTTPS.build(
      host: 'www.googleapis.com', path: '/books/v1/volumes',
      query: URI.encode_www_form({ q: query, maxResults: count, key: API_KEY.presence }.compact)
    )
    response = GoogleBooks.get(uri.to_s, timeout: TIMEOUT)
    if response.code == 429
      retry_at = Time.current + retry_wait(response.headers['retry-after'])
      write_cache(cooldown_key, retry_at, retry_at - Time.current)
      raise Unavailable.new(reason: :rate_limited, retry_at: retry_at)
    end
    raise Unavailable unless response.code == 200

    parse_books(response.parsed_response)
  end

  def self.parse_books(payload)
    raise Unavailable unless valid_payload?(payload)
    return [] if payload['totalItems'].zero?
    raise Unavailable unless payload['items'].is_a?(Array)

    books = payload['items'].filter_map do |item|
      GoogleBooks::Item.new(item)
    rescue StandardError
      # A broken volume must not discard the other usable books in the response.
      nil
    end
    raise Unavailable if books.empty?

    books
  end

  def self.valid_payload?(payload)
    payload.is_a?(Hash) && !payload.key?('error') && payload['totalItems'].is_a?(Integer) && payload['totalItems'] >= 0
  end

  def self.retry_wait(header)
    return [header.to_i, 1].max if header.to_s.match?(/\A\d+\z/)

    [(Time.httpdate(header.to_s) - Time.current).ceil, 1].max
  rescue ArgumentError
    DEFAULT_RETRY_WAIT
  end

  def self.read_cache(key)
    Rails.cache.read(key)
  rescue StandardError => e
    Rails.logger.warn("[GoogleBooksSearch] cache read failed: #{e.class}")
    nil
  end

  def self.write_cache(key, value, ttl)
    Rails.cache.write(key, value, expires_in: ttl)
  rescue StandardError => e
    Rails.logger.warn("[GoogleBooksSearch] cache write failed: #{e.class}")
  end

  def self.normalize(q)
    q.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def self.cache_key(query, count)
    digest = Digest::SHA256.hexdigest(query)
    "gbooks:search:v2:q=#{digest}:count=#{count}"
  end

  def self.cooldown_key
    "gbooks:cooldown:v1:#{Digest::SHA256.hexdigest(API_KEY.to_s)}"
  end

  private_class_method :failure_for, :fetch_books, :parse_books, :valid_payload?, :retry_wait, :read_cache, :write_cache, :normalize, :cache_key, :cooldown_key
end
