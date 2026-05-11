# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User sessions' do
  it 'sets the remember cookie when signing in with remember me' do
    user = create_user(email: 'remember@example.com', username: 'remember')

    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password',
        remember_me: '1'
      }
    }

    expect(response).to redirect_to(root_path)
    expect(cookies['remember_user_token']).to be_present
    expect(user.reload.remember_created_at).to be_present
  end

  it 'clears an existing remember token when signing in without remember me' do
    user = create_user(email: 'forget@example.com', username: 'forget')
    user.remember_me!

    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password',
        remember_me: '0'
      }
    }

    expect(response).to redirect_to(root_path)
    expect(cookies['remember_user_token']).to be_nil
    expect(user.reload.remember_created_at).to be_nil
  end

  it 're-renders the form immediately when signing in with an invalid password' do
    user = create_user(email: 'invalid@example.com', username: 'invalid')

    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'wrong-password',
        remember_me: '1'
      }
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Invalid Email or password.')
    expect(cookies['remember_user_token']).to be_nil
    expect(user.reload.remember_created_at).to be_nil
  end
end
