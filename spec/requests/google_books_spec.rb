# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Google Books' do
  it 'offers guests a save action and readable metadata for external search results' do
    google_result = Struct.new(:isbn, :title, :authors, :description) do
      def image_link(**)
        nil
      end
    end.new('9780261103344', 'The Hobbit: An Illustrated Edition', 'J.R.R. Tolkien',
            '<p>An <strong>adventure</strong>.</p><img src="x" onerror="alert(1)"><script>alert(1)</script>')
    allow(GoogleBooksSearch).to receive(:call).and_return([google_result])

    get search_google_books_path, params: { query: 'Hobbit', scope: 'title' },
                                  headers: { 'Turbo-Frame' => 'book-list' }

    expect(css_texts('.search-result__title')).to eq(['The Hobbit: An Illustrated Edition'])
    expect(css_texts('.search-result__author')).to eq(['J.R.R. Tolkien'])
    expect(css_texts('.search-result__isbn')).to eq(['ISBN 9780261103344'])
    expect(parsed_body.at_css('form[action="/book_selection"] input[name="query"]')['value']).to eq('Hobbit')
    expect(css_texts('button')).to include('Save to shelf')
    expect(parsed_body.css('details.search-result__description[open]')).to be_empty
    expect(css_texts('.search-result__description summary')).to include(a_string_matching(/Read description/))
    expect(css_texts('.search-result__description-text strong')).to eq(['adventure'])
    expect(parsed_body.css('.search-result__description-text script, .search-result__description-text img')).to be_empty
    expect(Book.count).to eq(0)
  end

  it 'does not offer a description disclosure for missing or empty descriptions' do
    book = Book.create!(isbn: 9780261103344, title: 'The Hobbit', author: 'J.R.R. Tolkien')
    allow(GoogleBooksSearch).to receive(:call).and_return([])

    [nil, '<p> </p>'].each do |description|
      book.update!(description:)
      get search_google_books_path, params: { query: 'Hobbit', scope: 'title' },
                                    headers: { 'Turbo-Frame' => 'book-list' }
      expect(response).to have_http_status(:ok)
      expect(parsed_body.css('.search-result__description')).to be_empty
    end
  end

  it 'renders a search form that submits explicitly without live search hooks' do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(
      parsed_body.css('form#google-books-search-form.search__form[data-action="submit->search#submit"]')
    ).to be_present
    expect(parsed_body.css('select[name="scope"][data-action="change->search#formChanged"]')).to be_present
    expect(parsed_body.css('input[name="query"][data-action="input->search#formChanged"]')).to be_present
    expect(parsed_body.css('select[name="scope"][data-action="change->search#filter"]')).to be_empty
    expect(parsed_body.css('input[name="query"][data-action="input->search#search"]')).to be_empty
    expect(css_texts('button.search__clear[data-action="click->search#clear"]')).to include('Clear')
    expect(css_texts('button.search__submit[type="submit"]')).to include('Search')
    expect(parsed_body.at_css('label[for="query"]').text).to eq('Search books')
    expect(parsed_body.at_css('label[for="scope"]').text).to eq('Search by')
    expect(parsed_body.at_css('input[name="query"]')['aria-describedby']).to eq('search-hint search-feedback')
    expect(parsed_body.at_css('button.search__clear').key?('hidden')).to be true
    expect(parsed_body.at_css('input[name="query"]')['maxlength']).to eq('500')
    expect(css_texts('template[data-search-target="loadingTemplate"]')).to include(a_string_matching(/Searching Books/))
  end

  it 'renders completed results for full-page searches without depending on JavaScript' do
    allow(GoogleBooksSearch).to receive(:call).with('intitle:Dune', count: 10, raise_on_error: true).and_return([])

    get search_google_books_path, params: { query: 'Dune', scope: 'title' }

    expect(response).to have_http_status(:ok)
    expect(css_texts('button.search__clear[data-action="click->search#clear"]')).to include('Clear')
    expect(parsed_body.css('turbo-frame#book-list[aria-busy="false"]')).to be_present
    expect(parsed_body.at_css('turbo-frame#book-list')['src']).to be_nil
    expect(response.body).to include('No matching books found')
    expect(parsed_body.css('.empty-state[role="status"]')).to be_present
    expect(parsed_body.at_css('input[name="query"]')['value']).to eq('Dune')
  end

  it 'rejects long or malformed ISBN searches without calling the provider' do
    expect(GoogleBooksSearch).not_to receive(:call)
    [['x' * 501, 'title'], ['not-an-isbn', 'isbn']].each do |query, scope|
      get search_google_books_path, params: { query:, scope: }, headers: { 'Turbo-Frame' => 'book-list' }
      expect(response).to have_http_status(:ok)
      expect(parsed_body.css('[role="alert"]')).to be_present
      expect(response.body).not_to include('No matching books found')
    end
    get search_google_books_path, params: { query: 'not-an-isbn', scope: 'isbn' }
    expect(parsed_body.at_css('input[name="query"]')['aria-invalid']).to eq('true')
  end

  it 'handles whitespace-only searches without a provider request' do
    expect(GoogleBooksSearch).not_to receive(:call)
    get search_google_books_path, params: { query: " \t\n ", scope: 'title' }
    expect(response).to have_http_status(:ok)
    expect(parsed_body.at_css('input[name="query"]')['value']).to eq('')
  end

  it 'preserves international queries and provides scope-specific guidance' do
    allow(GoogleBooksSearch).to receive(:call).and_return([])
    ['宮崎駿 📚', 'نجيب محفوظ'].each do |query|
      get search_google_books_path, params: { query:, scope: 'author' }
      expect(parsed_body.at_css('input[name="query"]')['value']).to eq(query)
      expect(parsed_body.at_css('input[name="query"]')['dir']).to eq('auto')
      expect(parsed_body.at_css('input[name="query"]')['placeholder']).to eq('Author name')
      expect(css_texts('#search-hint')).to eq(["Enter an author's name."])
    end
  end

  it 'shows a retry state for provider failures while preserving the query' do
    allow(GoogleBooksSearch).to receive(:call).and_raise(GoogleBooksSearch::Unavailable)
    get search_google_books_path, params: { query: 'Dune', scope: 'title' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("We couldn't reach Google Books.", 'Retry search')
    expect(response.body).not_to include('No matching books found')
    expect(parsed_body.at_css('input[name="query"]')['value']).to eq('Dune')
  end

  it 'keeps local matches visible when the provider is unavailable' do
    Book.create!(isbn: 9780261103344, title: 'The Hobbit', author: 'J.R.R. Tolkien')
    allow(GoogleBooksSearch).to receive(:call).and_raise(GoogleBooksSearch::Unavailable)
    get search_google_books_path, params: { query: 'Hobbit', scope: 'title' },
                                  headers: { 'Turbo-Frame' => 'book-list' }
    expect(css_texts('.search-result__title')).to eq(['The Hobbit'])
    expect(response.body).to include('Books already in Bookshelf are shown below.', 'Retry search')
  end

  it 'shows add-to-collection controls inside search result cards for signed-in users' do
    user = create_user(email: 'reader@example.com', username: 'reader')
    Book.create!(isbn: 9780261103344, title: 'The Hobbit', author: 'J.R.R. Tolkien')
    sign_in_as(user)
    allow(GoogleBooksSearch).to receive(:call).and_return([])

    get search_google_books_path,
        params: { query: 'Hobbit', scope: 'title' },
        headers: { 'Turbo-Frame' => 'book-list' }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.css('.books__card_footer .search-results__actions')).to be_present
    expect(css_texts('.search-results__actions_label')).to include('Save to collection')
    expect(css_texts('.books__card_footer .dropdown__button')).to include('Add to collection')
  end

  it 'does not duplicate a local book when Google returns the same ISBN as a string' do
    Book.create!(isbn: 9780261103344, title: 'The Hobbit', author: 'J.R.R. Tolkien')
    google_result = Struct.new(:isbn, :title, :authors, :description) do
      def image_link(**)
        nil
      end
    end.new('9780261103344', 'The Hobbit', 'J.R.R. Tolkien', 'A hobbit goes on an adventure.')
    allow(GoogleBooksSearch).to receive(:call).and_return([google_result])

    get search_google_books_path,
        params: { query: 'Hobbit', scope: 'title' },
        headers: { 'Turbo-Frame' => 'book-list' }

    expect(response).to have_http_status(:ok)
    expect(parsed_body.css('.search-results__item').size).to eq(1)
    expect(css_texts('.search-result__title')).to include('The Hobbit')
  end

  it 'updates a search result footer to in-collection without rerunning the search' do
    user = create_user(email: 'search-collector@example.com', username: 'search-collector')
    sign_in_as(user)
    footer_id = ApplicationController.helpers.search_result_actions_dom_id('9780261103344')

    post books_path,
         params: {
           book: {
             isbn: '9780261103344',
             title: 'The Hobbit',
             author: 'J.R.R. Tolkien',
             description: 'A hobbit goes on an adventure.',
             image_link: 'https://example.com/hobbit.jpg',
             slug: UserBook::WANT_TO_READ
           },
           source: 'search_results',
           search_result_footer_id: footer_id
         },
         as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    expect(response.body).to include(
      %(turbo-stream action="replace" target="#{footer_id}"),
      'In collection',
      'Open book'
    )
  end
end
