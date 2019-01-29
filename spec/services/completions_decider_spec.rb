require 'rails_helper'

describe CompletionsDecider do
  let(:desktop_user_agent) do
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ' \
    'AppleWebKit/537.36 (KHTML, like Gecko) ' \
    'Chrome/58.0.3029.110 Safari/537.36'
  end

  let(:mobile_user_agent) do
    'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_2 like Mac OS X) ' \
    'AppleWebKit/603.2.4 (KHTML, like Gecko) ' \
    'Version/10.0 Mobile/14F89 Safari/602.1'
  end

  let(:request_url_with_app_redirect_uri) do
    'http://test.com?redirect_uri=awesome.iphone.app://result'
  end

  let(:request_url_without_redirect_uri) do
    'http://test.com?SAMLRequest=foo'
  end

  let(:request_url_with_web_redirect_uri) do
    'http://test.com?redirect_uri=https://awesome-agency.gov/result'
  end

  describe '#go_back_to_mobile_app?' do
    context 'user agent is desktop and redirect_uri does not start with http' do
      it 'returns true' do
        decider = CompletionsDecider.new(
          user_agent: desktop_user_agent,
          request_url: request_url_with_app_redirect_uri,
        )

        expect(decider.go_back_to_mobile_app?).to eq true
      end
    end

    context 'user agent is desktop and redirect_uri starts with http' do
      it 'returns false' do
        decider = CompletionsDecider.new(
          user_agent: desktop_user_agent,
          request_url: request_url_with_web_redirect_uri,
        )

        expect(decider.go_back_to_mobile_app?).to eq false
      end
    end

    context 'user agent is desktop and redirect_uri does not exist' do
      it 'returns false' do
        decider = CompletionsDecider.new(
          user_agent: desktop_user_agent,
          request_url: request_url_without_redirect_uri,
        )

        expect(decider.go_back_to_mobile_app?).to eq false
      end
    end

    context 'user agent is mobile and redirect_uri does not exist' do
      it 'returns false' do
        decider = CompletionsDecider.new(
          user_agent: mobile_user_agent,
          request_url: request_url_without_redirect_uri,
        )

        expect(decider.go_back_to_mobile_app?).to eq false
      end
    end

    context 'user agent is mobile and redirect_uri starts with http' do
      it 'returns false' do
        decider = CompletionsDecider.new(
          user_agent: mobile_user_agent,
          request_url: request_url_with_web_redirect_uri,
        )

        expect(decider.go_back_to_mobile_app?).to eq false
      end
    end

    context 'user agent is mobile and redirect_uri does not start with http' do
      it 'returns false' do
        decider = CompletionsDecider.new(
          user_agent: mobile_user_agent,
          request_url: request_url_with_app_redirect_uri,
        )

        expect(decider.go_back_to_mobile_app?).to eq false
      end
    end
  end
end
