# frozen_string_literal: true

require 'test_helper'

class BookControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test 'book index paginates the library at 20 books' do
    create_books(prefix: 'Library', count: 21)

    get books_path

    assert_response :success
    assert_select '.books__item', count: 20
    assert_select '.books__pagination .pagy'
    assert_select '.books__title', text: 'Library 21', count: 1
    assert_select '.books__title', text: 'Library 1', count: 0
  end

  test 'user books overview paginates each shelf independently at 16 books' do
    user = create_user(email: 'sectioned@example.com', username: 'sectioned')
    create_user_books(user:, prefix: 'Read', slug: UserBook::READ, count: 17)
    create_user_books(user:, prefix: 'Reading', slug: UserBook::READING, count: 17)
    create_user_books(user:, prefix: 'To Read', slug: UserBook::WANT_TO_READ, count: 17)

    get user_books_path(username: user.username)

    assert_response :success
    assert_select '.books__item', count: 48
    assert_select '.books__pagination .pagy', count: 3
    assert_select '#books-shelf-section-read .books__pagination a[data-turbo-stream="true"]'
    assert_select '#books-shelf-section-reading .books__pagination a[data-turbo-stream="true"]'
    assert_select '#books-shelf-section-want_to_read .books__pagination a[data-turbo-stream="true"]'
    assert_select '.books__section_count', text: '17 books', count: 3
    assert_select '.books__section_subtitle', text: 'Finished books saved to this collection.'
    assert_select '.books__section_subtitle', text: 'Books currently in progress.'
    assert_select '.books__section_subtitle', text: 'Books queued up for later.'
    assert_includes response.body, 'read_page=2'
    assert_includes response.body, 'reading_page=2'
    assert_includes response.body, 'want_to_read_page=2'
    assert_includes response.body, 'bookshelf_slug=read'
    assert_includes response.body, 'bookshelf_slug=reading'
    assert_includes response.body, 'bookshelf_slug=want_to_read'

    get user_books_path(username: user.username, read_page: 2)

    assert_response :success
    assert_select '.books__item', count: 33
    assert_select '#readList .books__title', text: 'Read 1', count: 1
    assert_select '#readList .books__title', text: 'Read 17', count: 0
    assert_select '#currentlyReadingList .books__title', text: 'Reading 17', count: 1
    assert_select '#toReadList .books__title', text: 'To Read 17', count: 1
  end

  test 'user books pagination can replace only the requested shelf as turbo stream' do
    user = create_user(email: 'streamed-pages@example.com', username: 'streamed-pages')
    create_user_books(user:, prefix: 'Streamed Read', slug: UserBook::READ, count: 17)
    create_user_books(user:, prefix: 'Streamed Reading', slug: UserBook::READING, count: 17)

    get user_books_path(username: user.username, read_page: 2, bookshelf_slug: UserBook::READ),
        as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, 'target="books-shelf-section-read"'
    assert_includes response.body, 'Streamed Read 1'
    refute_includes response.body, 'Streamed Read 17'
    refute_includes response.body, 'books-shelf-section-reading'
    refute_includes response.body, 'Streamed Reading 17'
  end

  test 'filtered user bookshelf paginates at 16 books' do
    user = create_user(email: 'filtered@example.com', username: 'filtered')
    create_user_books(user:, prefix: 'Filtered Read', slug: UserBook::READ, count: 17)
    create_user_books(user:, prefix: 'Filtered Want', slug: UserBook::WANT_TO_READ, count: 2)

    get user_books_path(username: user.username, slug: UserBook::READ, page: 2)

    assert_response :success
    assert_select '.books__item', count: 1
    assert_select '.books__section_count', text: '17 books'
    assert_select '.books__section_subtitle', text: 'Finished books saved to this collection.'
    assert_includes response.body, 'Filtered Read 1'
    refute_includes response.body, 'Filtered Read 17'
    refute_includes response.body, 'Filtered Want 1'
  end

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

    with_google_books_search_call(->(*) { raise 'GoogleBooksSearch should not be called from books#create' }) do
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

  def with_google_books_search_call(callable)
    original = GoogleBooksSearch.method(:call)
    GoogleBooksSearch.define_singleton_method(:call) { |*args| callable.call(*args) }
    yield
  ensure
    GoogleBooksSearch.define_singleton_method(:call, original)
  end

  def create_books(prefix:, count:, isbn_offset: 0)
    Array.new(count) do |index|
      Book.create!(
        isbn: 9_780_000_000_000 + isbn_offset + index,
        title: "#{prefix} #{index + 1}",
        author: "#{prefix} Author"
      )
    end
  end

  def create_user_books(user:, prefix:, slug:, count:)
    isbn_offset = UserBook::USER_BOOK_STATUSES.index(slug) * 1_000
    create_books(prefix:, count:, isbn_offset:).each do |book|
      UserBook.create!(user:, book:, slug:)
    end
  end

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
