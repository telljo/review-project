# frozen_string_literal: true

module BookHelper
  def books_index_path_for(user: nil, slug: nil)
    if user.present?
      user_books_path(username: user.username, slug:)
    else
      books_path(slug:)
    end
  end

  def selected_bookshelf_label(slug)
    UserBook::SLUGS_READABLE.fetch(slug, 'All bookshelves')
  end

  def bookshelves_menu_options(user: nil)
    [
      { label: 'All', path: books_index_path_for(user:) },
      { label: 'Read', path: books_index_path_for(user:, slug: UserBook::READ) },
      { label: 'Currently reading', path: books_index_path_for(user:, slug: UserBook::READING) },
      { label: 'Want to read', path: books_index_path_for(user:, slug: UserBook::WANT_TO_READ) }
    ]
  end

  def user_bookshelf_sections(user:, read_books:, books_in_progress:, to_read_books:)
    [
      bookshelf_section(
        user:,
        slug: UserBook::READ,
        books: read_books,
        empty_title: "You haven't read any books yet",
        empty_subtitle: 'Once you add books to your collection and mark them as read, they will appear here.',
        sortable_id: 'readList'
      ),
      bookshelf_section(
        user:,
        slug: UserBook::READING,
        books: books_in_progress,
        empty_title: "You aren't reading any books currently",
        empty_subtitle: 'Once you add books to your collection and mark them as currently reading, they will appear here.',
        sortable_id: 'currentlyReadingList'
      ),
      bookshelf_section(
        user:,
        slug: UserBook::WANT_TO_READ,
        books: to_read_books,
        empty_title: "You haven't added any books to your want to read list yet",
        empty_subtitle: 'Once you add books to your collection and mark them as want to read, they will appear here.',
        sortable_id: 'toReadList'
      )
    ]
  end

  private

  def bookshelf_section(user:, slug:, books:, empty_title:, empty_subtitle:, sortable_id: nil)
    {
      title: UserBook::SLUGS_READABLE.fetch(slug),
      path: books_index_path_for(user:, slug:),
      shelf_slug: slug,
      books:,
      empty_title:,
      empty_subtitle:,
      sortable: sortable_id.present? ? sortable_options(sortable_id) : nil
    }
  end

  def sortable_options(sortable_id)
    {
      id: sortable_id,
      data: {
        controller: 'sortable',
        sortable_url: '/books/:id/move',
        sortable_source_id: sortable_id
      }
    }
  end
end
