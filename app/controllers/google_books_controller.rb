# frozen_string_literal: true

class GoogleBooksController < ApplicationController
  RECENTLY_ADDED_LIMIT = 9
  SEARCH_SCOPES = {
    "title" => "Title",
    "author" => "Author",
    "isbn" => "ISBN"
  }.freeze

  def index
    @query = ""
    @search_scope = "title"
    @search_results = []
    set_home_page_metrics

    @recently_added_books = Book.order(created_at: :desc).limit(RECENTLY_ADDED_LIMIT)
  end

  def search
    @recently_added_books = Book.order(created_at: :desc).limit(RECENTLY_ADDED_LIMIT)
    @query = search_query_param.to_s
    @search_scope = search_scope_param.presence_in(SEARCH_SCOPES.keys) || "title"
    @search_results = []
    set_home_page_metrics

    return unless @query.present?
    return if defer_search_results?

    load_search_results
  end

  private

  def defer_search_results?
    !turbo_frame_request?
  end

  def load_search_results
    normalized = @query.strip.downcase.gsub(/\s+/, " ")

    existing_book = existing_book_match(normalized)
    @search_results << existing_book if existing_book.present?

    remaining = 10 - @search_results.length
    return if remaining <= 0

    google_book_results = GoogleBooksSearch.call(google_books_query, count: remaining)

    google_book_results.each do |gbook|
      next unless gbook.isbn.present?
      next if @search_results.any? { |result| normalized_isbn_value(result.isbn) == normalized_isbn_value(gbook.isbn) }

      new_book = Book.new(
        title: gbook.title,
        author: gbook.authors,
        description: gbook.description,
        isbn: gbook.isbn
      )

      # This *shouldn't* trigger another API call; image_link is derived from the item,
      # but keep an eye on it if the gem does something clever.
      img = gbook.image_link(zoom: 5, curl: true)
      new_book.image_link = img if img.present?

      @search_results << new_book
    end
  end

  def existing_book_match(normalized_query)
    case @search_scope
    when "author"
      Book.where("LOWER(author) LIKE ?", "%#{normalized_query}%").first
    when "isbn"
      normalized_isbn = normalized_isbn_query
      return if normalized_isbn.blank?

      Book.where("CAST(isbn AS text) LIKE ?", "%#{normalized_isbn}%").first
    else
      Book.where("LOWER(title) LIKE ?", "%#{normalized_query}%").first
    end
  end

  def google_books_query
    prefix = case @search_scope
             when "author"
               "inauthor:"
             when "isbn"
               "isbn:"
             else
               "intitle:"
             end

    query_value = @search_scope == "isbn" ? normalized_isbn_query.presence || @query : @query

    "#{prefix}#{query_value}"
  end

  def normalized_isbn_query
    @query.to_s.gsub(/[^0-9Xx]/, "")
  end

  def normalized_isbn_value(value)
    value.to_s.gsub(/[^0-9Xx]/, "").downcase
  end

  def search_query_param
    params[:query].presence || params.dig(:google_books, :query)
  end

  def search_scope_param
    params[:scope].presence || params.dig(:google_books, :scope)
  end

  def set_home_page_metrics
    @books_count = Book.count
    @reviews_count = Review.count
  end
end
