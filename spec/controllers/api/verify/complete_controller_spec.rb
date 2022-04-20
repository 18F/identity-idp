require 'rails_helper'

describe Api::Verify::CompleteController do
  include PersonalKeyValidator
  include SamlAuthHelper

  def stub_idv_session
    stub_sign_in(user)
  end

  let(:password) { 'iambatman' }
  let(:user) { create(:user, :signed_up, password: password) }
  let(:applicant) do
    { first_name: 'Bruce',
      last_name: 'Wayne',
      address1: '123 Mansion St',
      address2: 'Ste 456',
      city: 'Gotham City',
      state: 'NY',
      zipcode: '10015' }
  end

  let(:pii) do
    { first_name: 'Bruce',
      last_name: 'Wayne',
      ssn: '900-90-1234' }
  end

  let(:profile) { subject.idv_session.profile }
  let(:key) { OpenSSL::PKey::RSA.new 2048 }
  let(:pub) { key.public_key }
  let(:jwt) { JWT.encode(pii, key, 'RS256', sub: user.uuid) }

  before do
    allow(IdentityConfig.store).to receive(:idv_private_key).
        and_return(Base64.strict_encode64(key.to_s))
    allow(IdentityConfig.store).to receive(:idv_public_key).
        and_return(Base64.strict_encode64(pub.to_s))
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
                             :before,
                             :confirm_two_factor_authenticated_for_api
                         )
    end
  end

  describe '#create' do
    context 'when the user is not signed in and submits the password' do
      it 'does not create a profile or return a key' do
        get :create, params: { password: 'iambatman', details: jwt }
        expect(JSON.parse(response.body)["personal_key"]).to be_nil
        expect(JSON.parse(response.body)["status"]).to eq "ERROR"
        expect(JSON.parse(response.body)["error"]).to eq "user is not fully authenticated"
      end
    end

    context 'when the user is signed in and submits the password' do
      before do
        stub_idv_session
      end

      it 'creates a profile and returns a key' do
        get :create, params: { password: 'iambatman', details: jwt }
        expect(JSON.parse(response.body)["personal_key"]).not_to be_nil
        expect(JSON.parse(response.body)["status"]).to eq "SUCCESS"
      end

      it 'does not create a profile and return a key when it has the wrong password' do
        get :create, params: { password: 'iamnotbatman', details: jwt }
        expect(JSON.parse(response.body)["personal_key"]).to be_nil
        expect(JSON.parse(response.body)["status"]).to eq "ERROR"
      end
    end
  end
end
