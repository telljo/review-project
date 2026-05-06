# frozen_string_literal: true

require 'test_helper'

class UserSessionsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = ['users']

  test 'signing in with remember me sets the remember cookie' do
    user = users(:accountant)

    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password',
        remember_me: '1'
      }
    }

    assert_redirected_to root_path
    assert cookies['remember_user_token'].present?
    assert user.reload.remember_created_at.present?
  end

  test 'signing in without remember me clears any existing remember token' do
    user = users(:accountant)
    user.remember_me!

    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password',
        remember_me: '0'
      }
    }

    assert_redirected_to root_path
    assert_nil cookies['remember_user_token']
    assert_nil user.reload.remember_created_at
  end

  test 'signing in with an invalid password re-renders the form immediately' do
    user = users(:accountant)

    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'wrong-password',
        remember_me: '1'
      }
    }

    assert_response :success
    assert_includes response.body, 'Invalid Email or password.'
    assert_nil cookies['remember_user_token']
    assert_nil user.reload.remember_created_at
  end
end
