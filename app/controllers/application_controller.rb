# frozen_string_literal: true

# Controller for the application
class ApplicationController < ActionController::Base
  before_action :turbo_frame_request_variant
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def devise_or_another_controller?
    devise_controller? || google_books_controller?
  end

  def google_books_controller?
    'google_books_controller'
  end

  def turbo_frame_request_variant
    request.variant = :turbo_frame if turbo_frame_request?
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |user_params|
      user_params.permit(:username, :email, :password, :password_confirmation)
    end

    devise_parameter_sanitizer.permit(:account_update) do |user_params|
      user_params.permit(:username, :email, :password, :current_password, :password_confirmation)
    end
  end
end
