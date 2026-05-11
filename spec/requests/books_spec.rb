# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Books' do
  describe 'GET /books' do
    it 'paginates the library at 20 books' do
      create_books(prefix: 'Library', count: 21)

      get books_path

      expect(response).to have_http_status(:ok)
      expect(parsed_body.css('.books__item').size).to eq(20)
      expect(parsed_body.css('.books__pagination .pagy')).to be_present
      expect(css_texts('.books__title')).to include('Library 21')
      expect(css_texts('.books__title')).not_to include('Library 1')
    end
  end

  describe 'GET /:username/books' do
    it 'paginates each shelf independently at 16 books' do
      user = create_user(email: 'sectioned@example.com', username: 'sectioned')
      create_user_books(user:, prefix: 'Read', slug: UserBook::READ, count: 17)
      create_user_books(user:, prefix: 'Reading', slug: UserBook::READING, count: 17)
      create_user_books(user:, prefix: 'To Read', slug: UserBook::WANT_TO_READ, count: 17)

      get user_books_path(username: user.username)

      expect(response).to have_http_status(:ok)
      expect(parsed_body.css('.books__item').size).to eq(48)
      expect(parsed_body.css('.books__pagination .pagy').size).to eq(3)
      expect(parsed_body.css('#books-shelf-section-read .books__pagination a[data-turbo-stream="true"]')).to be_present
      expect(
        parsed_body.css('#books-shelf-section-reading .books__pagination a[data-turbo-stream="true"]')
      ).to be_present
      expect(
        parsed_body.css('#books-shelf-section-want_to_read .books__pagination a[data-turbo-stream="true"]')
      ).to be_present
      expect(css_texts('.books__section_count')).to eq(['17 books', '17 books', '17 books'])
      expect(css_texts('.books__section_subtitle')).to include(
        'Finished books saved to this collection.',
        'Books currently in progress.',
        'Books queued up for later.'
      )
      expect(response.body).to include('read_page=2', 'reading_page=2', 'want_to_read_page=2')
      expect(response.body).to include('bookshelf_slug=read', 'bookshelf_slug=reading', 'bookshelf_slug=want_to_read')

      get user_books_path(username: user.username, read_page: 2)

      expect(response).to have_http_status(:ok)
      expect(parsed_body.css('.books__item').size).to eq(33)
      expect(css_texts('#readList .books__title')).to include('Read 1')
      expect(css_texts('#readList .books__title')).not_to include('Read 17')
      expect(css_texts('#currentlyReadingList .books__title')).to include('Reading 17')
      expect(css_texts('#toReadList .books__title')).to include('To Read 17')
    end

    it 'can replace only the requested shelf as turbo stream' do
      user = create_user(email: 'streamed-pages@example.com', username: 'streamed-pages')
      create_user_books(user:, prefix: 'Streamed Read', slug: UserBook::READ, count: 17)
      create_user_books(user:, prefix: 'Streamed Reading', slug: UserBook::READING, count: 17)

      get user_books_path(username: user.username, read_page: 2, bookshelf_slug: UserBook::READ),
          as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('target="books-shelf-section-read"', 'Streamed Read 1')
      expect(response.body).not_to include('Streamed Read 17', 'books-shelf-section-reading', 'Streamed Reading 17')
    end

    it 'paginates a filtered bookshelf at 16 books' do
      user = create_user(email: 'filtered@example.com', username: 'filtered')
      create_user_books(user:, prefix: 'Filtered Read', slug: UserBook::READ, count: 17)
      create_user_books(user:, prefix: 'Filtered Want', slug: UserBook::WANT_TO_READ, count: 2)

      get user_books_path(username: user.username, slug: UserBook::READ, page: 2)

      expect(response).to have_http_status(:ok)
      expect(parsed_body.css('.books__item').size).to eq(1)
      expect(css_texts('.books__section_count')).to include('17 books')
      expect(css_texts('.books__section_subtitle')).to include('Finished books saved to this collection.')
      expect(response.body).to include('Filtered Read 1')
      expect(response.body).not_to include('Filtered Read 17', 'Filtered Want 1')
    end
  end

  describe 'PATCH /books/:id/move' do
    it 'moves a signed-in user book to a different shelf' do
      user = create_user(email: 'reader@example.com', username: 'reader')
      book = Book.create!(isbn: 9780141182803, title: 'The Trial', author: 'Franz Kafka')
      user_book = UserBook.create!(user:, book:, slug: UserBook::WANT_TO_READ)

      sign_in_as(user)

      patch move_book_path(book), params: { slug: UserBook::READ }

      expect(response).to redirect_to(user_books_path(username: user.username, slug: UserBook::READ))
      expect(user_book.reload.slug).to eq(UserBook::READ)
    end

    it 'responds with turbo stream without reloading the page' do
      user = create_user(email: 'streamer@example.com', username: 'streamer')
      book = Book.create!(isbn: 9780140449198, title: 'Meditations', author: 'Marcus Aurelius')
      user_book = UserBook.create!(user:, book:, slug: UserBook::WANT_TO_READ)

      sign_in_as(user)

      patch move_book_path(book),
            params: { slug: UserBook::READ, view_slug: '' },
            as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(user_book.reload.slug).to eq(UserBook::READ)
      expect(response.body).to include('target="books-sections"')
    end

    it 'requires authentication' do
      user = create_user(email: 'owner@example.com', username: 'owner')
      book = Book.create!(isbn: 9780140449136, title: 'The Odyssey', author: 'Homer')
      UserBook.create!(user:, book:, slug: UserBook::READING)

      patch move_book_path(book), params: { slug: UserBook::READ }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'POST /books' do
    it 'adds a searched book without refetching Google Books' do
      user = create_user(email: 'collector@example.com', username: 'collector')
      sign_in_as(user)
      allow(GoogleBooksSearch).to receive(:call).and_raise('GoogleBooksSearch should not be called from books#create')

      expect do
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
      end.to change(Book, :count).by(1).and change(UserBook, :count).by(1)

      book = Book.find_by!(isbn: 9780140449266)
      user_book = UserBook.find_by!(user:, book:)
      expect(book.title).to eq('The Brothers Karamazov')
      expect(book.author).to eq('Fyodor Dostoevsky')
      expect(user_book.slug).to eq(UserBook::WANT_TO_READ)
      expect(response).to redirect_to(books_path)
    end

    it 'updates the shelf for a book already in the collection instead of duplicating it' do
      user = create_user(email: 'rereader@example.com', username: 'rereader')
      book = Book.create!(isbn: 9780140449181, title: 'The Iliad', author: 'Homer')
      user_book = UserBook.create!(user:, book:, slug: UserBook::WANT_TO_READ)

      sign_in_as(user)

      expect do
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
      end.not_to change(Book, :count)
      expect(UserBook.count).to eq(1)
      expect(user_book.reload.slug).to eq(UserBook::READ)
      expect(response).to redirect_to(books_path)
    end
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
end
