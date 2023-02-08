# frozen_string_literal: true

# Controller for the Reviews
class ReviewsController < ApplicationController
  before_action :set_review, only: %i[show edit update destroy]

  def index
    @reviews = current_user.reviews.ordered
  end

  def show; end

  def new
    @review = Review.new
  end

  def create
    @review = current_user.reviews.build(review_params)
    ap @review
    if @review.save
      respond_to do |format|
        format.html { redirect_to reviews_path, notice: 'Review was successfully created.' }
        format.turbo_stream { flash.now[:notice] = 'Review was successfully created.' }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

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
    @review = current_user.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:name, :content, :image)
  end
end
