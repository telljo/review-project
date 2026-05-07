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

  test 'moving a book can respond with turbo stream without reloading the page' do
    user = create_user(email: 'streamer@example.com', username: 'streamer')
    book = Book.create!(isbn: 9780140449198, title: 'Meditations', author: 'Marcus Aurelius')
    user_book = UserBook.create!(user:, book:, slug: UserBook::WANT_TO_READ)

    sign_in_as(user)

    patch move_book_path(book),
          params: { slug: UserBook::READ, view_slug: "" },
          as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal UserBook::READ, user_book.reload.slug
    assert_includes response.body, 'target="books-sections"'
  end

  test 'moving a book requires authentication' do
    user = create_user(email: 'owner@example.com', username: 'owner')
    book = Book.create!(isbn: 9780140449136, title: 'The Odyssey', author: 'Homer')
    UserBook.create!(user:, book:, slug: UserBook::READING)

    patch move_book_path(book), params: { slug: UserBook::READ }

    assert_redirected_to new_user_session_path
  end

  test 'signed in user can add a searched book without refetching Google Books' do
    user = create_user(email: 'collector@example.com', username: 'collector')

    sign_in_as(user)

    GoogleBooksSearch.stub(:call, ->(*) { raise 'GoogleBooksSearch should not be called from books#create' }) do
      assert_difference('Book.count', 1) do
        assert_difference('UserBook.count', 1) do
          post books_path, params: {
            book: {
              isbn: '9780140449266',
              title: 'The Brothers Karamazov',
              author: 'Fyodor Dostoevsky',
              description: 'A family drama and philosophical novel.',
              image_link: 'https://example.com/cover.jpg',
              slug: UserBook::WANT_TO_READ
            }
          }
        end
      end
    end

    book = Book.find_by!(isbn: 9780140449266)
    user_book = UserBook.find_by!(user:, book:)

    assert_equal 'The Brothers Karamazov', book.title
    assert_equal 'Fyodor Dostoevsky', book.author
    assert_equal UserBook::WANT_TO_READ, user_book.slug
    assert_redirected_to books_path
  end

  test 'adding a book already in the collection updates its shelf instead of duplicating it' do
    user = create_user(email: 'rereader@example.com', username: 'rereader')
    book = Book.create!(isbn: 9780140449181, title: 'The Iliad', author: 'Homer')
    user_book = UserBook.create!(user:, book:, slug: UserBook::WANT_TO_READ)

    sign_in_as(user)

    assert_no_difference('Book.count') do
      assert_no_difference('UserBook.count') do
        post books_path, params: {
          book: {
            isbn: book.isbn.to_s,
            title: book.title,
            author: book.author,
            description: book.description,
            image_link: book.image_link,
            slug: UserBook::READ
          }
        }
      end
    end

    assert_equal UserBook::READ, user_book.reload.slug
    assert_redirected_to books_path
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
