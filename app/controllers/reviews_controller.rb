# frozen_string_literal: true

# Controller for the Reviews
class ReviewsController < ApplicationController
  before_action :set_review, only: %i[show edit update destroy]

  before_action :authenticate_user!, except: %i[index show]

  def index
    @user = User.find_by(username: params[:username])
    @book = Book.find(params[:book_id]) if params[:book_id].present?

    @reviews = if @user.present?
                 @book.present? ? @user.reviews.ordered.where(book_id: @book.id) : @user.reviews.ordered
               elsif params[:book_id].present?
                 @book.reviews.ordered
               else
                 Review.all.ordered
               end
  end

  def show; end

  def new
    @book = Book.find(params[:book_id])
    @review = Review.new
  end

  def create
    @book = Book.find(params[:book_id])
    @review = current_user.reviews.build(review_params)
    @review.book = @book
    @review.user = current_user
    if @review.save
      respond_to do |format|
        format.html { redirect_to reviews_path, notice: 'Review was successfully created.' }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @review.update(review_params)
      respond_to do |format|
        format.html { redirect_to reviews_path, notice: 'Review was successfully updated.' }
        format.turbo_stream { flash.now[:notice] = 'Review was successfully updated.' }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review.destroy

    respond_to do |format|
      format.html { redirect_to reviews_path, notice: 'Review was successfully deleted.' }
      format.turbo_stream { flash.now[:notice] = 'Review was successfully deleted.' }
    end
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:content, :rating, :book_id)
  end
end
