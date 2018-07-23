require 'rails_helper'

describe 'visiting sign in page with invalid user params' do
  it 'does not raise an exception' do
    get new_user_session_path, params: { user: 'test@test.com' }
  end
end
