# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Test::OidcTestController do
  before do
    # Do nothing
  end

  after do
    # Do nothing
  end

  describe '#index' do

  end
  describe '#auth_request' do

  end

  describe '#logout' do
    let(:expected_redirect) do
      uri = URI(openid_connect_logout_url)
      uri.query = ''
      uri.fragment = ''
      uri.query = "token=TEST:#{CGI.escape(serialized_token)}"
      uri.to_s
    end

    it 'returns a redirect' do
      allow(subject).to receive(:user_session)

      get :logout, params: { }

      expect(response).to redirect_to(openid_connect_logout_url)
    end
  end
end
