# frozen_string_literal: true

# Controller for Books
class BooksController < ApplicationController
  before_action :authenticate_user!, only: %i[create destroy move]
  before_action :set_user_book, only: %i[move destroy]

  def index
    @user = User.find_by(username: params[:username])
    @slug = params[:slug]
    @owner_view = @user.present? && user_signed_in? && @user == current_user
    @books = if @user.present?
               if @slug.present?
                 @user.books.where(user_books: { slug: @slug }).ordered.distinct
               else
                 @read_books = @user.books.where(user_books: { slug: UserBook::READ }).ordered.distinct
                 @books_in_progress = @user.books.where(user_books: { slug: UserBook::READING }).ordered.distinct
                 @to_read_books = @user.books.where(user_books: { slug: UserBook::WANT_TO_READ }).ordered.distinct
                 @user.books.ordered
               end
             else
               Book.all.ordered
             end
  end

  def show
    render :show, locals: { book: Book.find_by(id: params[:id]) || Book.find_by(slug: params[:isbn]) }
  end

  def move
    previous_slug = @user_book.slug
    @user_book.update!(slug: params[:slug])
    message = "#{@book.title} moved to #{UserBook::SLUGS_READABLE.fetch(@user_book.slug)}."

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = message
        load_bookshelf_state(user: current_user, slug: params[:view_slug])
        @moved_from_slug = previous_slug
        @moved_to_slug = @user_book.slug
      end
      format.html do
        redirect_back fallback_location: current_user_collection_path,
                      notice: message
      end
      format.any { head :ok }
    end
  end

  def select
    id = params[:id]
    if id.present?
      @book = Book.find_by(id:)
    else
      isbn = params[:isbn].strip
      query_string = "isbn:#{isbn}"
      gbook = GoogleBooksSearch.call(query_string, count: 1).first

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
    attrs = normalized_create_book_params
    slug = attrs.delete(:slug)
    @search_result_footer_id = params[:search_result_footer_id]

    ActiveRecord::Base.transaction do
      @book = Book.find_or_initialize_by(isbn: attrs[:isbn])
      @book.assign_attributes(attrs) if @book.new_record?
      @book.save!

      user_book = current_user.user_books.find_or_initialize_by(book: @book)
      user_book.slug = slug
      user_book.save!
    end

    respond_to do |format|
      format.html { redirect_to books_path, notice: "#{@book.title} was added to your collection." }
      format.turbo_stream { flash.now[:notice] = "#{@book.title} was added to your collection." }
    end
  rescue ActiveRecord::RecordInvalid
    @book ||= Book.new(attrs.except(:isbn, :slug))

    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.turbo_stream do
        flash.now[:alert] = "We couldn't add that book to your collection."
        render :create, status: :unprocessable_entity
      end
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
    @user_book = current_user.user_books.find_by_book_id!(params[:id])
  end

  def create_book_params
    params.require(:book).permit(:isbn, :slug, :title, :author, :description, :image_link)
  end

  def normalized_create_book_params
    create_book_params.to_h.transform_values do |value|
      value.is_a?(String) ? value.strip : value
    end.symbolize_keys
  end

  def load_bookshelf_state(user:, slug: nil)
    @user = user
    @slug = slug.presence
    @owner_view = @user.present? && user_signed_in? && @user == current_user

    if @slug.present?
      @books = @user.books.where(user_books: { slug: @slug }).ordered.distinct
    else
      @read_books = @user.books.where(user_books: { slug: UserBook::READ }).ordered.distinct
      @books_in_progress = @user.books.where(user_books: { slug: UserBook::READING }).ordered.distinct
      @to_read_books = @user.books.where(user_books: { slug: UserBook::WANT_TO_READ }).ordered.distinct
    end
  end

  def current_user_collection_path
    return books_path unless current_user&.username.present?

    user_books_path(username: current_user.username, slug: @user_book.slug)
  end
end
