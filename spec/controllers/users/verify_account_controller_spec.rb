require 'rails_helper'

RSpec.describe Users::VerifyAccountController do
  include Features::LocalizationHelper

  let(:has_pending_profile) { true }
  let(:success) { true }
  let(:otp) { 'abc123' }
  let(:submitted_otp) { otp }
  let(:pii_attributes) { Pii::Attributes.new_from_hash(otp: otp) }
  let(:pending_profile) { build(:profile) }

  before do
    user = stub_sign_in
    decorated_user = stub_decorated_user_with_pending_profile(user)
    allow(decorated_user).to receive(:needs_profile_phone_verification?).and_return(false)
    allow(decorated_user).to receive(:needs_profile_usps_verification?).
      and_return(has_pending_profile)
    allow(controller).to receive(:decrypted_pii).and_return(pii_attributes)
  end

  describe '#index' do
    subject(:action) do
      get(:index)
    end

    context 'user has pending profile' do
      it 'renders page' do
        action

        expect(response).to render_template('users/verify_account/index')
      end
    end

    context 'user does not have pending profile' do
      let(:has_pending_profile) { false }

      it 'redirects to account page' do
        action

        expect(response).to redirect_to(account_url)
      end
    end
  end

  describe '#create' do
    subject(:action) do
      post(
        :create,
        verify_account_form: {
          otp: submitted_otp,
        }
      )
    end

    context 'with a valid form' do
      it 'redirects to the account verification page' do
        action

        expect(response).to redirect_to(verify_account_path)
      end
    end

    context 'with an invalid form' do
      let(:submitted_otp) { 'the-wrong-otp' }

      it 'renders the index page to show errors' do
        action

        expect(response).to render_template('users/verify_account/index')
      end
    end
  end
end
