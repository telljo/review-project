# frozen_string_literal: true

class GoogleBooksController < ApplicationController
  def index
    @google_books = []
    google_book_results = GoogleBooks.search(params[:title], { count: 10 })

    google_book_results.each do |gbook|
      @google_books.append(Book.new(title: gbook.title, author: gbook.authors, isbn: gbook.isbn))
    end
  end
end
