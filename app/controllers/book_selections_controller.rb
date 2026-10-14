# frozen_string_literal: true

class BookSelectionsController < ApplicationController
  before_action :authenticate_user!, only: %i[show update]
  before_action :load_selection, only: %i[show update]

  def create
    isbn = params[:isbn].to_s.strip
    unless isbn.match?(/\A\d{1,13}\z/)
      redirect_to root_path, alert: 'Choose a book with an ISBN to save it.'
      return
    end

    session[:book_selection] = {
      'isbn' => isbn,
      'title' => params[:title].to_s.truncate(200),
      'query' => params[:query].to_s.truncate(200),
      'scope' => params[:scope].presence_in(GoogleBooksController::SEARCH_SCOPES.keys) || 'title'
    }
    destination = user_signed_in? ? book_selection_path : new_user_registration_path
    redirect_to destination, status: :see_other
  end

  def show; end

  def update
    unless @book
      render :show, status: :unprocessable_entity
      return
    end

    @selected_slug = params[:slug]
    ActiveRecord::Base.transaction do
      @book.save!
      user_book = current_user.user_books.find_or_initialize_by(book: @book)
      user_book.update!(slug: @selected_slug)
    end
    session.delete(:book_selection)
    redirect_to user_books_path(username: current_user.username, slug: @selected_slug),
                notice: "#{@book.title} was added to #{UserBook::SLUGS_READABLE.fetch(@selected_slug)}.",
                status: :see_other
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "We couldn't save that book. Choose a shelf and try again."
    render :show, status: :unprocessable_entity
  end

  def destroy
    selection = session.delete(:book_selection)
    search_path = search_google_books_path(
      query: selection&.fetch('query', nil),
      scope: selection&.fetch('scope', nil)
    )
    redirect_to search_path, status: :see_other
  end

  private

  def load_selection
    selection = session[:book_selection]
    if selection.present?
      @book = Book.find_by(isbn: selection['isbn']) || selected_google_book(selection['isbn'])
    else
      redirect_to root_path
    end
  end

  def selected_google_book(isbn)
    result = GoogleBooksSearch.call("isbn:#{isbn}", count: 1).find { |book| book.isbn.to_s.to_i == isbn.to_i }
    return unless result

    Book.new(isbn: isbn, title: result.title, author: Array(result.authors).join(', '),
             description: result.description, image_link: result.image_link(zoom: 5, curl: true))
  end
end
