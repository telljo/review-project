# frozen_string_literal: true

class UsersController < ApplicationController # rubocop:disable Style/Documentation
  def show
    @user = User.find_by_username(params[:username])
  end
end
