# frozen_string_literal: true

class GoogleBooksController < ApplicationController
  def index
    @google_books = []

    # Books that have an average review of 4 or higher
    @popular_books = Book.joins('LEFT OUTER JOIN reviews ON reviews.book_id = books.id')
                         .group('books.id')
                         .having('AVG(reviews.rating) >= ?', 4)
                         .where('reviews.id IS NOT NULL')

    existing_book = Book.where('LOWER(title) LIKE ?', "%#{params[:title]}%").first
    if existing_book.present?
      @existing_book = existing_book
      @google_books.append(@existing_book)
    end

    google_book_results = GoogleBooks.search(params[:title], { count: 10 - @google_books.length })

    google_book_results.each do |gbook|
      @google_books.append(Book.new(title: gbook.title, author: gbook.authors, isbn: gbook.isbn)) if gbook.isbn.present?
    end
  end
end
