require 'rails_helper'

RSpec.describe 'session store cookie migration' do
  def extract_session_uuid(response, session_key:)
    cookie_str = response.headers['Set-Cookie'].
      split("\n").
      find { |cookie| cookie.starts_with?(session_key) }
    cookie_str.split(';').first.split('=').last
  end

  it 'allows the app to read session data when the old key is present' do
    get root_path

    session_uuid = extract_session_uuid(response, session_key: '_identity_idp_session')

    get test_session_data_path, headers: { 'Cookie' => "_upaya_session=#{session_uuid}" }

    expect(JSON.parse(response.body)).to include(
      'events' => { 'Sign in page visited' => true },
      'first_event' => true,
      'first_path_visit' => true,
      'first_success_state' => true,
      'paths_visited' => { '/' => true },
      'success_states' => { 'GET|/|Sign in page visited' => true },
    )
  end

  it 'sends both old and new keys with set-cookie' do
    get root_path

    response_cookies = response.headers['Set-Cookie'].split("\n")

    old_cookie_header = response_cookies.find { |c| c.starts_with?('_upaya_session=') }
    new_cookie_header = response_cookies.find { |c| c.starts_with?('_identity_idp_session=') }

    expect(old_cookie_header).to be_present
    expect(new_cookie_header).to be_present

    expect(old_cookie_header.sub('_upaya_session', '_identity_idp_session')).
      to eq(new_cookie_header)
  end
end
