# frozen_string_literal: true

# Controller for Books
class BooksController < ApplicationController
  def index
    @books = current_user.books.ordered
  end

  def show; end

  def select
    gbook = GoogleBooks.search(params[:isbn]).first

    @book = Book.new(
      isbn: gbook.isbn,
      title: gbook.title,
      author: gbook.authors,
      description: gbook.description
    )

    @book.image_link = gbook.image_link(zoom: 5, curl: true) if gbook.image_link(zoom: 5, curl: true).present?

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "#{@book.title} selected" }
    end
  end

  def new
    @book = Book.new
  end

  def create
    if Book.find_by(isbn: create_book_params[:isbn]).present?
      @book = Book.find_by(isbn: create_book_params[:isbn])
    else
      g_book = GoogleBooks.search(params[:isbn]).first
      ap g_book

      @book = Book.create(
        isbn: g_book.isbn,
        title: g_book.title,
        author: g_book.authors,
        description: g_book.description,
        image_link: g_book.image_link(zoom: 5)
      )
    end

    UserBook.create!(book_id: @book.id, user_id: current_user.id)

    if @book.save
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "#{@book.title} was added to your collection." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  private

  def book_params
    params.require(:book).permit(:title)
  end

  def create_book_params
    params.permit(:isbn)
  end
end
