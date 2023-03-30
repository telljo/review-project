# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'pages#home'

  devise_scope :user do
    # Redirests signing out users back to sign-in
    get 'users', to: 'devise/sessions#new'
  end

  devise_for :users
  resources :reviews
  resources :google_books
  resources :books do
    collection do
      get :select
      get :search
    end
  end
end
