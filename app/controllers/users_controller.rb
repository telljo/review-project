# frozen_string_literal: true

class UsersController < ApplicationController
  def show
    @user = User.find_by!(username: params[:username])
    @owner_view = current_user == @user
    @book_count = @user.books.count
    @review_count = @user.reviews.count
    @shelf_counts = @user.user_books.group(:slug).count
    @shelf_previews = [UserBook::READING, UserBook::READ, UserBook::WANT_TO_READ].index_with do |slug|
      @user.user_books.where(slug:).includes(:book).order(updated_at: :desc, id: :desc).limit(3).map(&:book)
    end
    @recent_reviews = @user.reviews.ordered.includes(:book).with_rich_text_content.limit(3)
  end
end
