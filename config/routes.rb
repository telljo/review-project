# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'google_books#index'

  devise_scope :user do
    # Redirests signing out users back to sign-in
    get 'users', to: 'devise/sessions#new'
  end

  devise_for :users
  resources :reviews
  resources :google_books do
    collection do
      get :search
    end
  end
  resources :books do
    member do
      patch :move
      patch :select
    end
    collection do
      get :search
    end
    resources :reviews, only: %i[index]
  end
  get ':username', to: 'users#show', as: 'user'
  get ':username/books', to: 'books#index', as: 'user_books'
  get ':username/reviews', to: 'reviews#index', as: 'user_reviews'
end
