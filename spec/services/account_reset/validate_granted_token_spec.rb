require 'rails_helper'

describe AccountReset::ValidateGrantedToken do
  include AccountResetHelper

  let(:expired_token_message) do
    t('errors.account_reset.granted_token_expired', app_name: APP_NAME)
  end
  let(:expired_token_error) { { token: [expired_token_message] } }
  let(:user) { create(:user) }
  let(:request) { FakeRequest.new }
  let(:analytics) { FakeAnalytics.new }

  let(:service_provider) do
    create(
      :service_provider,
      active: true,
      redirect_uris: ['http://localhost:7654/auth/result'],
      ial: 2,
    )
  end

  describe '#call' do
  end
end
