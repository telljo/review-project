# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Google Books recovery' do
  it 'returns timeout guidance and keeps the query, scope, and local book available' do
    Book.create!(isbn: 9780261103344, title: 'The Hobbit', author: 'J.R.R. Tolkien')
    allow(GoogleBooksSearch).to receive(:call).and_raise(GoogleBooksSearch::Unavailable.new(reason: :timeout))
    get search_google_books_path, params: { query: 'Tolkien', scope: 'author' }
    expect(response).to have_http_status(:ok)
    expect(parsed_body.at_css('[data-search-response]')['data-query']).to eq('Tolkien')
    expect(parsed_body.at_css('[data-search-response]')['data-scope']).to eq('author')
    expect(css_texts('.search-results__notice-title')).to eq(['Google Books took too long to respond.'])
    expect(css_texts('.search-result__title')).to eq(['The Hobbit'])
    expect(parsed_body.at_css('[data-recovery-retry]')['form']).to eq('google-books-search-form')
  end

  it 'returns a rate-limit deadline for both full-page and Turbo searches' do
    retry_at = Time.current + 30.seconds
    error = GoogleBooksSearch::Unavailable.new(reason: :rate_limited, retry_at: retry_at)
    allow(GoogleBooksSearch).to receive(:call).and_raise(error)
    [{}, { 'Turbo-Frame' => 'book-list' }].each do |headers|
      get search_google_books_path, params: { query: 'Dune', scope: 'title' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(parsed_body.at_css('[data-search-response]')['data-retry-at']).to eq(retry_at.iso8601(3))
      expect(parsed_body.at_css('[data-recovery-countdown]')['aria-live']).to eq('off')
      expect(response.body).not_to include('No matching books found')
    end
  end

  it 'recovers on retry without losing the original search' do
    allow(GoogleBooksSearch).to receive(:call).and_raise(GoogleBooksSearch::Unavailable)
    get search_google_books_path, params: { query: 'Dune', scope: 'title' }
    allow(GoogleBooksSearch).to receive(:call).and_return([])
    get search_google_books_path, params: { query: 'Dune', scope: 'title' }, headers: { 'Turbo-Frame' => 'book-list' }
    expect(parsed_body.css('.search-results__notice')).to be_empty
    expect(parsed_body.at_css('[data-search-response]')['data-query']).to eq('Dune')
    expect(response.body).to include('No matching books found')
  end
end
