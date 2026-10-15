# frozen_string_literal: true

class BookShelvesController < ApplicationController
  before_action :set_book
  before_action :remember_selection, unless: :user_signed_in?
  before_action :authenticate_user!

  def update
    @selected_slug = params[:slug]
    unless UserBook::USER_BOOK_STATUSES.include?(@selected_slug)
      @shelf_error = 'Choose a shelf, then try again.'
      render 'books/show', locals: { book: @book }, status: :unprocessable_content
      return
    end

    current_user.with_lock do
      user_book = current_user.user_books.find_or_initialize_by(book: @book)
      # A repeated Save must not move a book that has already been saved.
      user_book.update!(slug: @selected_slug) if user_book.new_record? || params[:intent] == 'move'
    end
    session.delete(:book_selection) if session.dig(:book_selection, 'book_id') == @book.id
    redirect_to book_path(@book, anchor: 'save-to-shelf'), status: :see_other
  rescue ActiveRecord::RecordInvalid
    @shelf_error = "We couldn't save this book. Your shelf choice is still selected. Try again."
    render 'books/show', locals: { book: @book }, status: :unprocessable_content
  end

  private

  def set_book
    @book = Book.find(params[:id])
  end

  def remember_selection
    session[:book_selection] = {
      'book_id' => @book.id,
      'title' => @book.title.truncate(200),
      'slug' => params[:slug].presence_in(UserBook::USER_BOOK_STATUSES)
    }
  end
end
