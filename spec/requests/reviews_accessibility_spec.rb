# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accessible review ratings' do
  let(:user) { create_user(email: 'rating-reader@example.com', username: 'rating-reader') }
  let(:book) { Book.create!(isbn: 9780141182803, title: 'The Trial', author: 'Franz Kafka') }
  let(:review) { Review.create!(user:, book:, rating: 0, content: 'A considered reading note.') }

  it 'renders a native rating group and an explicitly labeled editor' do
    sign_in_as(user)
    get new_review_path(book_id: book.id)

    expect(css_texts('.review-rating legend')).to eq(['Rating (out of 5)'])
    choices = parsed_body.css('input[type="radio"][name="review[rating]"]')
    expect(choices.map { |choice| choice['value'] }).to eq(%w[1 2 3 4 5 0])
    expect(choices.all? { |choice| choice.key?('required') }).to be(true)
    expect(parsed_body.css('input[type="hidden"][name="review[rating]"]')).to be_empty
    editor = parsed_body.at_css('trix-editor')
    label = parsed_body.at_css("##{editor['aria-labelledby']}")
    expect(label.text).to eq('Your review')
    expect(label['for']).to eq(editor['id'])
  end

  it 'saves every existing score without a JavaScript hidden-field update' do
    sign_in_as(user)
    (0..5).each do |score|
      post reviews_path, params: { book_id: book.id, review: { rating: score, content: "A #{score}-star reading note." } }
      expect(response).to redirect_to(reviews_path)
      expect(user.reviews.ordered.first.rating).to eq(score)
    end
    expect(user.reviews.count).to eq(6)
  end

  it 'rejects invalid scores and preserves the draft' do
    sign_in_as(user)
    [6, -1, '1.5', ''].each do |score|
      post reviews_path, params: { book_id: book.id, review: { rating: score, content: 'Keep this reading note.' } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Keep this reading note.')
      expect(parsed_body.css('.error-message[role="alert"]')).to be_present
      expect(parsed_body.at_css('.review-rating')['aria-describedby']).to eq(parsed_body.at_css('[role="alert"]')['id'])
    end
    expect(user.reviews).to be_empty
  end

  it 'retains the chosen score when the review text fails validation' do
    sign_in_as(user)
    post reviews_path, params: { book_id: book.id, review: { rating: 4, content: '' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(parsed_body.at_css('input[name="review[rating]"][checked]')['value']).to eq('4')
    expect(css_texts('[role="alert"]')).to include(a_string_including("Content can't be blank"))
    expect(parsed_body.at_css('trix-editor')['aria-invalid']).to eq('true')
    expect(parsed_body.at_css('trix-editor')['aria-describedby']).to eq(parsed_body.at_css('[role="alert"]')['id'])
  end

  it 'gives simultaneous inline editors independent control and label identifiers' do
    sign_in_as(user)
    other_review = Review.create!(user:, book:, rating: 3, content: 'Another review to edit independently.')
    get edit_review_path(review)
    first_ids = parsed_body.css('.review-form [id]').map { |node| node['id'] }
    get edit_review_path(other_review)
    second_ids = parsed_body.css('.review-form [id]').map { |node| node['id'] }
    expect(first_ids & second_ids).to be_empty
  end

  it 'exposes an existing zero rating as a checked, editable native choice' do
    sign_in_as(user)
    get edit_review_path(review)
    expect(parsed_body.at_css('input[name="review[rating]"][checked]')['value']).to eq('0')

    patch review_path(review), params: { review: { rating: 3, content: 'An updated reading note.' } }, as: :turbo_stream
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('3 out of 5', "target=\"review_#{review.id}\"")
    expect(review.reload.rating).to eq(3)
  end

  it 'provides numeric text and hides decorative stars on public review surfaces' do
    get review_path(review)
    expect(css_texts('.rating-display')).to eq(['0 out of 5'])
    expect(parsed_body.at_css('.rating-display__stars')['aria-hidden']).to eq('true')
    get reviews_path
    expect(css_texts('.rating-display')).to include('0 out of 5')
  end

  it 'does not let another reader edit or delete a review' do
    review
    other = create_user(email: 'other-review-reader@example.com', username: 'other-review-reader')
    sign_in_as(other)
    get edit_review_path(review)
    expect(response).to have_http_status(:not_found)
    patch review_path(review), params: { review: { rating: 5, content: 'Someone else changed this.' } }
    expect(response).to have_http_status(:not_found)
    delete review_path(review)
    expect(response).to have_http_status(:not_found)
    expect(review.reload.rating).to eq(0)
    expect(review.content.to_plain_text).to eq('A considered reading note.')
  end

  it 'keeps the reviewed book fixed when updating the rating' do
    sign_in_as(user)
    other_book = Book.create!(isbn: 9780140449198, title: 'Meditations', author: 'Marcus Aurelius')
    patch review_path(review), params: { review: { rating: 5, content: 'Updated.', book_id: other_book.id } }
    expect(response).to redirect_to(reviews_path)
    expect(review.reload.book_id).to eq(book.id)
  end
end
