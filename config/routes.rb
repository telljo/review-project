# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'pages#home'

  devise_scope :user do
    # Redirests signing out users back to sign-in
    get 'users', to: 'devise/sessions#new'
  end

  devise_for :users
  resources :reviews
  resources :books do
    collection do
      get :select
    end
  end
end
