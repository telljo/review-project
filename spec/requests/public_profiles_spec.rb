# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public reading profiles' do
  let(:user) { create_user(email: 'profile-reader@example.com', username: 'profile-reader') }

  it 'shows bounded shelf previews and recent reviews from only this reader' do
    UserBook::USER_BOOK_STATUSES.each do |slug|
      create_user_books(user:, prefix: slug, slug:, count: 4)
    end
    books = user.books.order(:id).to_a
    4.times { |index| Review.create!(user:, book: books[index], rating: index, content: "Reading note #{index + 1}. " * 30) }
    other = create_user(email: 'separate-profile@example.com', username: 'separate-profile')
    Review.create!(user: other, book: books.first, rating: 5, content: 'A different reader’s distinct note.')

    get user_path(username: user.username)

    expect(response).to have_http_status(:ok)
    expect(css_texts('h1')).to eq([user.username])
    expect(css_texts('.books__hero_meta .books__stat_value')).to eq(%w[12 4])
    expect(parsed_body.css('.books__hero_meta a').map { |link| link['href'] }).to eq(
      [user_books_path(username: user.username), user_reviews_path(username: user.username)]
    )
    expect(parsed_body.css('.profile-page__book').size).to eq(9)
    expect(parsed_body.css('.profile-page__review_list article').size).to eq(3)
    expect(response.body).to include('Reading note 4.', 'Reading note 3.', 'Reading note 2.')
    expect(response.body).not_to include('Reading note 1.', 'A different reader’s distinct note.')
    expect(css_texts('.profile-page__review_excerpt').all? { |text| text.length <= 240 }).to be(true)
    expect(parsed_body.at_css('a[aria-label="View Currently reading shelf"]')['href']).to eq(
      user_books_path(username: user.username, slug: UserBook::READING)
    )
  end

  it 'gives visitors a calm empty profile without instructions to edit it' do
    get user_path(username: user.username)
    expect(response.body).to include('Nothing shared yet', 'This reader hasn’t added any books or reviews yet.')
    expect(response.body).not_to include('Search for books', 'Drop a book', 'Start your reading record')
  end

  it 'gives the owner an actionable first-use state' do
    sign_in_as(user)
    get user_path(username: user.username)
    expect(response.body).to include('Start your reading record', 'Search for books')
    expect(response.body).not_to include('Nothing shared yet')
  end

  it 'uses visitor-specific copy on partially empty profiles and shelves' do
    create_user_books(user:, prefix: 'Read', slug: UserBook::READ, count: 1)
    get user_path(username: user.username)
    expect(response.body).to include('No books on this shelf yet.', 'This reader hasn’t shared any reviews yet.')
    expect(response.body).not_to include('You haven’t', 'Drop a book')

    get user_books_path(username: user.username)
    expect(response.body).not_to include('Drop a book', 'data-sortable-url', 'Drag a book')
    expect(response.body).to include('No books on this shelf yet', 'profile-reader hasn’t added any books to this shelf.')
  end

  it 'preserves shelf movement controls and guidance for the owner' do
    create_user_books(user:, prefix: 'Read', slug: UserBook::READ, count: 1)
    sign_in_as(user)
    get user_books_path(username: user.username)
    expect(response.body).to include('Drop a book here', 'data-sortable-url')
  end

  it 'returns not found for an unknown reader' do
    get user_path(username: 'missing-reader')
    expect(response).to have_http_status(:not_found)
  end
end
