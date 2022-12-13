require 'rails_helper'

describe UserPivCacSetupForm do
  let(:form) { described_class.new(user: user, token: token, nonce: nonce, name: 'Card 1') }

  let(:nonce) { 'nonce' }
  let(:user) { create(:user) }

  describe '#submit' do
    before(:each) do
      allow(PivCacService).to receive(:decode_token).with(token) { token_response }
    end

    context 'when token is valid' do
      let(:token) { 'good-token' }
      let(:x509_dn_uuid) { 'random-uuid-for-x509-subject' }

      let(:token_response) do
        {
          'uuid' => x509_dn_uuid,
          'subject' => 'x509-subject',
          'nonce' => nonce,
        }
      end

      it 'returns FormResponse with success: true' do
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'piv_cac' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        user.reload
        expect(TwoFactorAuthentication::PivCacPolicy.new(user).enabled?).to eq true
        expect(user.piv_cac_configurations.first.x509_dn_uuid).to eq x509_dn_uuid
      end

      it 'sends a recovery information changed event' do
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

        form.submit
      end

      context 'and a user already has a piv/cac associated' do
        let(:user) { create(:user, :with_piv_or_cac) }

        it 'returns FormResponse with success: true' do
          result = instance_double(FormResponse)
          extra = { multi_factor_auth_method: 'piv_cac' }

          expect(FormResponse).to receive(:new).
            with(success: true, errors: {}, extra: extra).and_return(result)
          expect(form.submit).to eq result
          expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq true
        end
      end

      context 'and a piv/cac is already associated with another user' do
        let(:other_user) { create(:user, :with_piv_or_cac) }
        let(:x509_dn_uuid) { other_user.piv_cac_configurations.first.x509_dn_uuid }

        it 'returns FormResponse with success: false' do
          result = instance_double(FormResponse)
          extra = { multi_factor_auth_method: 'piv_cac', key_id: nil }

          expect(FormResponse).to receive(:new).
            with(success: false,
                 errors: { type: 'piv_cac.already_associated' },
                 extra: extra).and_return(result)
          expect(form.submit).to eq result
          expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq false
          expect(form.error_type).to eq 'piv_cac.already_associated'
        end
      end
    end

    context 'when token is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => nonce, 'key_id' => 'foo' }
      end

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'piv_cac', key_id: 'foo' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: { type: 'token.bad' }, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq false
        expect(form.error_type).to eq 'token.bad'
      end
    end

    context 'when nonce is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => bad_nonce, 'key_id' => 'foo' }
      end
      let(:bad_nonce) { nonce + 'X' }

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'piv_cac', key_id: 'foo' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: { type: 'token.invalid' }, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(form.error_type).to eq 'token.invalid'
      end
    end

    context 'when token is missing' do
      let(:token) {}

      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'piv_cac' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq false
      end
    end
  end
end
