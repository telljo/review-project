# frozen_string_literal: true

require 'test_helper'

class GoogleBookControllerTest < ActionDispatch::IntegrationTest
  test 'root search form submits explicitly without live search hooks' do
    get root_path

    assert_response :success
    assert_select 'form#google-books-search-form.search__form[data-action="submit->search#submit"]'
    assert_select 'select[name="scope"][data-action="change->search#formChanged"]'
    assert_select 'input[name="query"][data-action="input->search#formChanged"]'
    assert_select 'select[name="scope"][data-action="change->search#filter"]', 0
    assert_select 'input[name="query"][data-action="input->search#search"]', 0
    assert_select 'button.search__clear[hidden][data-action="click->search#clear"]', text: /Clear/
    assert_select 'button.search__submit[type="submit"]', text: /Search/
    assert_select 'template[data-search-target="loadingTemplate"]', text: /Searching Books/
  end

  test 'full page search loads the list via turbo frame for manual url visits' do
    GoogleBooksSearch.stub(:call, ->(*) { flunk 'GoogleBooksSearch should be deferred until the frame request' }) do
      get search_google_books_path, params: { query: 'Dune', scope: 'title' }
    end

    assert_response :success
    assert_select 'button.search__clear[data-action="click->search#clear"]', text: /Clear/
    assert_select 'button.search__clear[hidden]', 0
    assert_select 'turbo-frame#book-list.search-results.search-results--loading[aria-busy="true"]'
    assert_includes response.body, 'Searching Books'
    assert_includes response.body, 'query=Dune&amp;scope=title'
  end

  test 'signed in user sees add to collection controls inside search result cards' do
    user = create_user(email: 'reader@example.com', username: 'reader')
    Book.create!(isbn: 9780261103344, title: 'The Hobbit', author: 'J.R.R. Tolkien')

    sign_in_as(user)

    GoogleBooksSearch.stub(:call, ->(*) { [] }) do
      get search_google_books_path,
          params: { query: 'Hobbit', scope: 'title' },
          headers: { 'Turbo-Frame' => 'book-list' }
    end

    assert_response :success
    assert_select '.books__card_footer .search-results__actions'
    assert_select '.search-results__actions_label', text: /Save to collection/
    assert_select '.books__card_footer .dropdown__button', text: /Add to collection/
  end

  test 'search does not duplicate a local book when google returns the same isbn as a string' do
    Book.create!(isbn: 9780261103344, title: 'The Hobbit', author: 'J.R.R. Tolkien')
    google_result = Struct.new(:isbn, :title, :authors, :description) do
      def image_link(**)
        nil
      end
    end.new('9780261103344', 'The Hobbit', 'J.R.R. Tolkien', 'A hobbit goes on an adventure.')

    GoogleBooksSearch.stub(:call, ->(*) { [google_result] }) do
      get search_google_books_path,
          params: { query: 'Hobbit', scope: 'title' },
          headers: { 'Turbo-Frame' => 'book-list' }
    end

    assert_response :success
    assert_select '.search-results__item', 1
    assert_select '.books__title', text: /The Hobbit/, count: 1
  end

  test 'adding a search result updates its footer to in collection without rerunning the search' do
    user = create_user(email: 'collector@example.com', username: 'collector')
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

    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html', response.media_type
    assert_includes response.body, %(turbo-stream action="replace" target="#{footer_id}")
    assert_includes response.body, 'In collection'
    assert_includes response.body, 'Open book'
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
