require 'rails_helper'
require 'lambdas/account_reset_lambda'

describe AccountResetLambda do
  let(:subject) { AccountResetLambda }
  let(:auth_token) { 'abc123' }
  let(:test_url) { 'https://fakelogin.gov/path1/path2' }

  describe '#send_notifications' do
    it 'calls the url supplying the auth token in the header' do
      suppress_output do
        stub_request(:post, test_url).
          with(headers: { 'X-Api-Auth-Token' => auth_token }).
          to_return(status: 200, body: '', headers: {})

        subject.new(test_url, auth_token).send_notifications
      end
    end
  end
end
