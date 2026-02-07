# frozen_string_literal: true

class GoogleBooksController < ApplicationController
  def index
    # Books that have an average review of 4 or higher
    @popular_books = Book.joins('LEFT OUTER JOIN reviews ON reviews.book_id = books.id')
                         .group('books.id')
                         .having('AVG(reviews.rating) >= ?', 4)
                         .where('reviews.id IS NOT NULL')
  end

  def search
    @query = params.dig(:google_books, :title).to_s
    @search_results = []

    if @query.present?
      existing_book = Book.where('LOWER(title) LIKE ?', "%#{@query.downcase}%").first
      @search_results << existing_book if existing_book.present?

      google_book_results = GoogleBooks.search(@query, count: 10 - @search_results.length)
      google_book_results.each do |gbook|
        next unless gbook.isbn.present?

        new_book = Book.new(
          title: gbook.title,
          author: gbook.authors,
          description: gbook.description,
          isbn: gbook.isbn
        )
        img = gbook.image_link(zoom: 5, curl: true)
        new_book.image_link = img if img.present?

        @search_results << new_book
      end
    end
  end
end
