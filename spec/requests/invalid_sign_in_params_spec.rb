require 'rails_helper'

RSpec.describe 'sign in params' do
  context 'visiting sign in page with invalid user params' do
    it 'does not raise an exception' do
      get new_user_session_path, params: { user: 'test@test.com' }
    end
  end

  context 'when the request_id param is present but with a nil value' do
    it 'does not raise an error' do
      get new_user_session_path, params: { request_id: nil }
    end
  end
end
