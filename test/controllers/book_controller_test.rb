# frozen_string_literal: true

require 'test_helper'

class BookControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test 'signed in user can move a book to a different shelf' do
    user = create_user(email: 'reader@example.com', username: 'reader')
    book = Book.create!(isbn: 9780141182803, title: 'The Trial', author: 'Franz Kafka')
    user_book = UserBook.create!(user:, book:, slug: UserBook::WANT_TO_READ)

    sign_in_as(user)

    patch move_book_path(book), params: { slug: UserBook::READ }

    assert_redirected_to user_books_path(username: user.username, slug: UserBook::READ)
    assert_equal UserBook::READ, user_book.reload.slug
  end

  test 'moving a book requires authentication' do
    user = create_user(email: 'owner@example.com', username: 'owner')
    book = Book.create!(isbn: 9780140449136, title: 'The Odyssey', author: 'Homer')
    UserBook.create!(user:, book:, slug: UserBook::READING)

    patch move_book_path(book), params: { slug: UserBook::READ }

    assert_redirected_to new_user_session_path
  end

  private

  def create_user(email:, username:)
    User.create!(
      email:,
      username:,
      password: 'password',
      password_confirmation: 'password'
    )
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password'
      }
    }
  end
end
