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
  let(:key) { OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_private_key)) }
  let(:jwt) { JWT.encode({ pii: pii, metadata: {} }, key, 'RS256', sub: user.uuid) }

  before do
    allow(IdentityConfig.store).to receive(:idv_api_enabled).and_return(true)
  end

  describe 'before_actions' do
    it 'includes before_actions from Api::BaseController' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated_for_api,
      )
    end
  end

  describe '#create' do
    context 'when the user is not signed in and submits the password' do
      it 'does not create a profile or return a key' do
        post :create, params: { password: 'iambatman', details: jwt }
        expect(JSON.parse(response.body)['personal_key']).to be_nil
        expect(response.status).to eq 401
        expect(JSON.parse(response.body)['error']).to eq 'user is not fully authenticated'
      end
    end

    context 'when the user is signed in and submits the password' do
      before do
        stub_idv_session
      end

      it 'creates a profile and returns a key' do
        post :create, params: { password: 'iambatman', details: jwt }
        expect(JSON.parse(response.body)['personal_key']).not_to be_nil
        expect(response.status).to eq 200
      end

      it 'does not create a profile and return a key when it has the wrong password' do
        post :create, params: { password: 'iamnotbatman', details: jwt }
        expect(JSON.parse(response.body)['personal_key']).to be_nil
        expect(response.status).to eq 400
      end
    end

    context 'when the idv api is not enabled' do
      before do
        allow(IdentityConfig.store).to receive(:idv_api_enabled).and_return(false)
      end

      it 'responds with not found' do
        post :create, params: { password: 'iambatman', details: jwt }
        expect(response.status).to eq 404
        expect(JSON.parse(response.body)['error']).
          to eq "The page you were looking for doesn't exist"
      end
    end
  end
end
