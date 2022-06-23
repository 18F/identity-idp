require 'rails_helper'

RSpec.describe Idv::UserBundleTokenizer do
  let(:public_key) do
    OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_public_key))
  end
  let(:user) { create(:user) }
  let(:sp) { create(:service_provider) }
  let(:user_session) do
    {
      idv: {
        applicant: {
          'first_name' => 'Ada',
          'last_name' => 'Lovelace',
          'ssn' => '900900900',
          'phone' => '+1 410-555-1212',
        },
        address_verification_mechanism: 'phone',
        user_phone_confirmation: true,
        vendor_phone_confirmation: true,
      },
    }
  end
  let(:idv_session) do
    Idv::Session.new(user_session: user_session, current_user: user, service_provider: sp)
  end
  subject do
    Idv::UserBundleTokenizer.new(user: user, idv_session: idv_session)
  end

  context 'when initialized with data' do
    it 'encodes a signed JWT' do
      token = subject.token
      decorator = Api::UserBundleDecorator.new(user_bundle: token, public_key: public_key)

      expect(decorator.pii).to eq user_session[:idv][:applicant]
    end
  end
end
