# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Book selections' do
  let(:selection) do
    { isbn: '9780261103344', title: 'The Hobbit', query: 'Hobbit', scope: 'title' }
  end

  def choose_book
    post book_selection_path, params: selection
  end

  it 'keeps an unsaved book through sign-up, then saves it to the chosen shelf' do
    google_book = Struct.new(:isbn, :title, :authors, :description) do
      def image_link(**)
        nil
      end
    end.new(selection[:isbn], 'The Hobbit', ['J.R.R. Tolkien'], 'A hobbit goes on an adventure.')
    allow(GoogleBooksSearch).to receive(:call).with('isbn:9780261103344', count: 1).and_return([google_book])

    choose_book
    expect(response).to redirect_to(new_user_registration_path)
    follow_redirect!
    expect(response.body).to include("You're saving", 'The Hobbit', 'Back to search')

    post user_registration_path, params: {
      user: { username: 'new-reader', email: 'new-reader@example.com',
              password: 'password', password_confirmation: 'password' }
    }
    expect(response).to redirect_to(book_selection_path)
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(css_texts('.search-result__title')).to eq(['The Hobbit'])
    expect(parsed_body.css('input[type="radio"][name="slug"]').size).to eq(3)
    expect(Book.find_by(isbn: selection[:isbn])).to be_nil

    patch book_selection_path, params: { slug: UserBook::READ }

    user = User.find_by!(username: 'new-reader')
    expect(response).to redirect_to(user_books_path(username: user.username, slug: UserBook::READ))
    expect(user.user_books.first.slug).to eq(UserBook::READ)
    expect(user.books.first.description).to eq('A hobbit goes on an adventure.')
    get book_selection_path
    expect(response).to redirect_to(root_path)
  end

  it 'keeps the selection through an invalid login and uses the existing book after login' do
    user = create_user(email: 'selection@example.com', username: 'selection-reader')
    Book.create!(isbn: selection[:isbn], title: 'The Hobbit', author: 'J.R.R. Tolkien')
    choose_book
    get new_user_session_path
    expect(response.body).to include('The Hobbit')

    post user_session_path, params: { user: { email: user.email, password: 'wrong-password' } }
    expect(response.body).to include('Invalid email or password.', 'The Hobbit')

    expect(GoogleBooksSearch).not_to receive(:call)
    sign_in_as(user)
    expect(response).to redirect_to(book_selection_path)
    follow_redirect!
    expect(response.body).to include('Choose a shelf', 'The Hobbit')
  end

  it 'cancels back to the original search without redirecting a later login into the selection' do
    user = create_user(email: 'cancel@example.com', username: 'cancel-reader')
    choose_book
    delete book_selection_path
    expect(response).to redirect_to(search_google_books_path(query: 'Hobbit', scope: 'title'))
    sign_in_as(user)
    expect(response).to redirect_to(root_path)
  end

  it 'retains an unavailable selection and offers retry without saving the wrong edition' do
    user = create_user(email: 'retry@example.com', username: 'retry-reader')
    choose_book
    sign_in_as(user)
    allow(GoogleBooksSearch).to receive(:call).and_return([])
    get book_selection_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Your selection is still saved.', 'Try again')
    expect(user.books).to be_empty
  end

  it 'rejects malformed selection identifiers' do
    post book_selection_path, params: selection.merge(isbn: 'https://example.com')
    expect(response).to redirect_to(root_path)
  end

  it 'rejects an invalid shelf without losing the selected book' do
    user = create_user(email: 'shelf@example.com', username: 'shelf-reader')
    Book.create!(isbn: selection[:isbn], title: 'The Hobbit', author: 'J.R.R. Tolkien')
    choose_book
    sign_in_as(user)
    patch book_selection_path, params: { slug: 'invalid-shelf' }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include('Choose a shelf and try again.', 'The Hobbit')
    expect(user.books).to be_empty
    patch book_selection_path, params: { slug: UserBook::WANT_TO_READ }
    expect(user.user_books.first.slug).to eq(UserBook::WANT_TO_READ)
  end
end
