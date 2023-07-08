# frozen_string_literal: true

# Controller for Books
class BooksController < ApplicationController
  before_action :set_user_book, only: %i[move destroy]

  before_action :authenticate_user!, only: %i[create destroy]

  def index
    @user = User.find_by(username: params[:username])
    @slug = params[:slug]
    @books = if @user.present?
               if @slug.present?
                 @user.books.where(user_books: { slug: @slug }).ordered.distinct
               else
                 @user.books.ordered
                 @read_books = @user.books.where(user_books: { slug: UserBook::READ }).ordered.distinct
                 @books_in_progress = @user.books.where(user_books: { slug: UserBook::READING }).ordered.distinct
                 @to_read_books = @user.books.where(user_books: { slug: UserBook::WANT_TO_READ }).ordered.distinct
               end
             else
               Book.all.ordered
             end
  end

  def show
    @book = Book.find_by(id: params[:id]) || Book.find_by(slug: params[:isbn])
  end

  def move
    @user_book.update!(slug: params[:slug])
    head :ok
  end

  def select
    id = params[:id]
    if id.present?
      @book = Book.find_by(id:)
    else
      isbn = params[:isbn].strip
      query_string = "isbn:#{isbn}"
      gbook = GoogleBooks.search(query_string).first

      @book = Book.new(
        isbn:,
        title: gbook.title,
        author: gbook.authors,
        description: gbook.description
      )
      @book.image_link = gbook.image_link(zoom: 5, curl: true) if gbook.image_link(zoom: 5, curl: true).present?
    end

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "#{@book.title} selected" }
    end
  end

  def new
    @book = Book.new
  end

  def create
    isbn = create_book_params[:isbn].strip
    query_string = "isbn:#{isbn}"

    if Book.find_by(isbn: create_book_params[:isbn]).present?
      @book = Book.find_by(isbn: create_book_params[:isbn])
    else
      gbook = GoogleBooks.search(query_string).first

      @book = Book.create(
        isbn:,
        title: gbook.title,
        author: gbook.authors,
        description: gbook.description,
        image_link: gbook.image_link(zoom: 5)
      )
    end
    UserBook.create!(book_id: @book.id, user_id: current_user.id, slug: create_book_params[:slug].strip)

    if @book.save
      respond_to do |format|
        format.html { redirect_to books_path, notice: "#{@book.title} was added to your collection." }
        format.turbo_stream { flash.now[:notice] = "#{@book.title} was added to your collection." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def destroy
    @book = @user_book.book
    @user_book.destroy

    respond_to do |format|
      format.html { redirect_to books_path, notice: "#{@book.title} was removed from your collection." }
      format.turbo_stream { flash.now[:notice] = "#{@book.title} was removed from your collection." }
    end
  end

  private

  def set_user_book
    @book = Book.find(params[:id])
    @user_book = current_user.user_books.find_by_book_id(params[:id])
  end

  def create_book_params
    params.require(:book).permit(:isbn, :slug)
  end
end
