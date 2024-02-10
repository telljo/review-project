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
    @search_results = []

    existing_book = Book.where('LOWER(title) LIKE ?', "%#{params[:google_books][:title]}%").first
    @search_results.append(existing_book) if existing_book.present?

    google_book_results = GoogleBooks.search(params[:google_books][:title], { count: 10 - @search_results.length })

    google_book_results.each do |gbook|
      next unless gbook.isbn.present?

      new_book = Book.new(
        title: gbook.title,
        author: gbook.authors,
        description: gbook.description,
        isbn: gbook.isbn
      )
      new_book.image_link = gbook.image_link(zoom: 5, curl: true) if gbook.image_link(zoom: 5, curl: true).present?

      @search_results.append(new_book)
    end
  end
end
