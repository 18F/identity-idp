require 'rails_helper'

RSpec.describe 'Invalid UTF-8 encoding in form input' do
  let(:good_email) { 'test@test.com' }
  let(:bad_email) { "test@\xFFbar\xF8.com" }
  let(:bad_request_id) { "\xFFbar\xF8" }

  it 'returns 400 when email is bad' do
    params = { user: { email: bad_email } }
    post new_user_session_path, params: params

    expect(response.status).to eq 400
  end

  it 'returns 400 when request_id is bad' do
    params = { user: { email: good_email, request_id: bad_request_id } }
    post new_user_session_path, params: params

    expect(response.status).to eq 400
  end

  it 'returns 400 when email is a hash with a bad email' do
    params = { user: { email: { foo: bad_email }, request_id: bad_request_id } }
    post new_user_session_path, params: params

    expect(response.status).to eq 400
  end

  it 'returns 400 when email is an array with a bad email' do
    params = { user: { email: [bad_email], request_id: bad_request_id } }
    post new_user_session_path, params: params

    expect(response.status).to eq 400
  end

  it 'returns 400 when email is a symbol' do
    params = { user: { email: :foo, request_id: bad_request_id } }
    post new_user_session_path, params: params

    expect(response.status).to eq 400
  end

  it 'returns 400 when request_id in password form is bad' do
    params = {
      password_reset_email_form: { email: 'test@test.com', request_id: "test\xFFbar\xF8" },
    }

    post '/users/password', params: params

    expect(response.status).to eq 400
  end
end
