# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    include Devise::Controllers::Rememberable

    def create
      self.resource = warden.authenticate!(auth_options)
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      sync_remember_me(resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end

    private

    def sync_remember_me(resource)
      remember_me_requested? ? remember_me(resource) : forget_me(resource)
    end

    def remember_me_requested?
      Devise::TRUE_VALUES.include?(sign_in_params[:remember_me])
    end
  end
end
