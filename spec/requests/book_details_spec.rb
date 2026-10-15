# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Saving from book details' do
  let(:book) { Book.create!(isbn: 9780261103344, title: 'The Selected Edition', author: 'A Reader', description: 'A long description. ' * 40) }
  let(:user) { create_user(email: 'detail-reader@example.com', username: 'detail-reader') }

  def begin_selection
    post book_selection_path, params: { book_id: book.id, title: 'Untrusted title', return_to: 'https://example.com' }
  end

  def resume_selection
    get book_selection_path
    expect(response).to redirect_to(book_path(book, anchor: 'save-to-shelf'))
    follow_redirect!
  end

  it 'offers the guest save action before a disclosed long description' do
    get book_path(book)

    expect(response).to have_http_status(:ok)
    expect(parsed_body.css('input[name="book_id"]').first['value']).to eq(book.id.to_s)
    expect(response.body.index('Save to shelf')).to be < response.body.index('About this book')
    expect(parsed_body.css('details.book__description')).to be_present
    expect(css_texts('.book__rating')).to eq(['No ratings yet'])
  end

  it 'keeps the exact book through invalid login without another ISBN lookup' do
    Book.create!(isbn: 9780261103345, title: 'Another Edition', author: 'Someone Else')
    expect(GoogleBooksSearch).not_to receive(:call)
    begin_selection
    expect(response).to redirect_to(new_user_registration_path)
    follow_redirect!
    expect(response.body).to include(book.title, 'Back to book')
    expect(response.body).not_to include('Untrusted title')
    expect(parsed_body.css('label[for="user_email"]').size).to eq(1)
    expect(parsed_body.at_css('label[for="user_email"]')['class'].to_s).not_to include('visually-hidden')

    post user_session_path, params: { user: { email: user.email, password: 'wrong-password' } }
    expect(response.body).to include('Invalid email or password.', book.title, 'Back to book')
    expect(css_texts('.devise-form__error[role="alert"]')).to eq(['Invalid email or password.'])
    sign_in_as(user)
    expect(response).to redirect_to(book_selection_path)
    resume_selection
    expect(parsed_body.css('.book__shelf_choices input[type="radio"]').size).to eq(3)
    expect(parsed_body.at_css('input[name="slug"][checked]')['value']).to eq(UserBook::WANT_TO_READ)
  end

  it 'keeps the book through failed signup and returns to its inline shelf choice after signup' do
    begin_selection
    post user_registration_path, params: {
      user: { username: 'new-detail-reader', email: 'new-detail@example.com', password: 'short', password_confirmation: 'other' }
    }
    expect(response.body).to include(book.title, 'Back to book')
    expect(css_texts('.devise-form__error[role="alert"]')).to include(a_string_including('Password'))
    post user_registration_path, params: {
      user: { username: 'new-detail-reader', email: 'new-detail@example.com', password: 'password', password_confirmation: 'password' }
    }
    expect(response).to redirect_to(book_selection_path)
    resume_selection
    expect(css_texts('.book__title')).to eq([book.title])
    expect(UserBook.count).to eq(0)
  end

  it 'retains the shelf choice when a session has expired' do
    patch shelve_book_path(book), params: { slug: UserBook::READING, intent: 'save' }
    expect(response).to redirect_to(new_user_session_path)
    sign_in_as(user)
    resume_selection
    expect(parsed_body.at_css('input[name="slug"][checked]')['value']).to eq(UserBook::READING)
  end

  it 'saves the actual record and stays on the book with durable shelf feedback' do
    begin_selection
    sign_in_as(user)
    expect(GoogleBooksSearch).not_to receive(:call)

    expect do
      patch shelve_book_path(book), params: { slug: UserBook::READING, intent: 'save' }
    end.to change(UserBook, :count).by(1).and change(Book, :count).by(0)
    expect(response).to redirect_to(book_path(book, anchor: 'save-to-shelf'))
    follow_redirect!
    expect(css_texts('.book__saved')).to eq(['Saved to Reading'])
    expect(parsed_body.at_css('.book__shelf_link')['href']).to eq(user_books_path(username: user.username, slug: UserBook::READING))
    expect(user.user_books.first.book_id).to eq(book.id)
    get book_selection_path
    expect(response).to redirect_to(root_path)
  end

  it 'makes repeated saves idempotent and moves only on an explicit change-shelf action' do
    sign_in_as(user)
    patch shelve_book_path(book), params: { slug: UserBook::READING, intent: 'save' }
    patch shelve_book_path(book), params: { slug: UserBook::READ, intent: 'save' }
    expect(user.user_books.count).to eq(1)
    expect(user.user_books.first.slug).to eq(UserBook::READING)

    patch shelve_book_path(book), params: { slug: UserBook::READ, intent: 'move' }
    follow_redirect!
    expect(css_texts('.book__saved')).to eq(['Saved to Read'])
    expect(user.user_books.count).to eq(1)
  end

  it 'keeps an invalid move editable and leaves the existing shelf intact' do
    user_book = UserBook.create!(user: user, book: book, slug: UserBook::READING)
    sign_in_as(user)
    patch shelve_book_path(book), params: { slug: 'unknown', intent: 'move' }

    expect(response).to have_http_status(:unprocessable_content)
    expect(css_texts('[role="alert"]')).to include('Choose a shelf, then try again.')
    expect(parsed_body.at_css('.book__shelf_editor')['open']).not_to be_nil
    expect(user_book.reload.slug).to eq(UserBook::READING)
  end

  it 'preserves a valid shelf choice after a failed save and permits retry' do
    sign_in_as(user)
    allow_any_instance_of(UserBook).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(UserBook.new))
    patch shelve_book_path(book), params: { slug: UserBook::READ, intent: 'save' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Your shelf choice is still selected.')
    expect(parsed_body.at_css('input[name="slug"][checked]')['value']).to eq(UserBook::READ)
    expect(user.books).to be_empty

    allow_any_instance_of(UserBook).to receive(:save!).and_call_original
    patch shelve_book_path(book), params: { slug: UserBook::READ, intent: 'save' }
    expect(user.user_books.first.slug).to eq(UserBook::READ)
  end

  it 'cancels to the originating book and clears the handoff' do
    begin_selection
    delete book_selection_path
    expect(response).to redirect_to(book_path(book))
    sign_in_as(user)
    expect(response).to redirect_to(root_path)
  end

  it 'does not replace a removed book with another edition and can cancel safely' do
    begin_selection
    book.destroy!
    expect(GoogleBooksSearch).not_to receive(:call)
    sign_in_as(user)
    get book_selection_path
    expect(response.body).to include("We couldn't load your selected book.")
    delete book_selection_path
    expect(response).to redirect_to(books_path)
  end
end
