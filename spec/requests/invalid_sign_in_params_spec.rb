require 'rails_helper'

describe 'visiting sign in page with invalid user params' do
  it 'raises ActionController::ParameterMissing' do
    params = { user: 'test@test.com' }
    message_string = 'param is missing or the value is empty: #permit called on String'

    expect { get new_user_session_path, params: params }.
      to raise_error(ActionController::ParameterMissing, message_string)
  end
end

context 'when the request_id param is present but with a nil value' do
  it 'does not raise an error' do
    get new_user_session_path, params: { request_id: nil }
  end
end
