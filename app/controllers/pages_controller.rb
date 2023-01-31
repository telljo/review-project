# frozen_string_literal: true

# Controller for the pages
class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  def home; end
end
