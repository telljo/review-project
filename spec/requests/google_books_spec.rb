# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Google Books' do
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
    expect(css_texts('template[data-search-target="loadingTemplate"]')).to include(a_string_matching(/Searching Books/))
  end

  it 'loads the list via turbo frame for manual full-page search url visits' do
    allow(GoogleBooksSearch).to receive(:call).and_raise('GoogleBooksSearch should be deferred until the frame request')

    get search_google_books_path, params: { query: 'Dune', scope: 'title' }

    expect(response).to have_http_status(:ok)
    expect(css_texts('button.search__clear[data-action="click->search#clear"]')).to include('Clear')
    expect(
      parsed_body.css('turbo-frame#book-list.search-results.search-results--loading[aria-busy="true"]')
    ).to be_present
    expect(response.body).to include('Searching Books', 'query=Dune&amp;scope=title')
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
    expect(css_texts('.books__title')).to include('The Hobbit')
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
