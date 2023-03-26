# frozen_string_literal: true

# Controller for Books
class BooksController < ApplicationController
  def index
    @books = []
    if params[:title].present?
      google_books = GoogleBooks.search(params[:title], { count: 10 })
      google_books.each do |gbook|
        @books.append(Book.new(title: gbook.title, author: gbook.authors, isbn: gbook.isbn))
      end
    else
      @books = Book.first(10)
    end
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
    @book = Book.build(book_params)
    if @book.save
      respond_to do |format|
        format.html { redirect_to books_path, notice: 'Book was successfully created.' }
        format.turbo_stream { flash.now[:notice] = 'Book was successfully created.' }
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
end
