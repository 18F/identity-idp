require 'rails_helper'

RSpec.describe UserPivCacSetupForm do
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
          'key_id' => 'foo',
        }
      end

      it 'returns FormResponse with success: true' do
        expect(form.submit.to_h).to eq(
          success: true,
          multi_factor_auth_method: 'piv_cac',
          key_id: 'foo',
        )
        user.reload
        expect(TwoFactorAuthentication::PivCacPolicy.new(user).enabled?).to eq true
        expect(user.piv_cac_configurations.first.x509_dn_uuid).to eq x509_dn_uuid
      end

      context 'and a user already has a piv/cac associated' do
        let(:user) { create(:user, :with_piv_or_cac) }

        it 'returns FormResponse with success: true' do
          expect(form.submit.to_h).to eq(
            success: true,
            multi_factor_auth_method: 'piv_cac',
            key_id: 'foo',
          )
          expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq true
        end
      end

      context 'and a piv/cac is already associated with another user' do
        let(:other_user) { create(:user, :with_piv_or_cac) }
        let(:x509_dn_uuid) { other_user.piv_cac_configurations.first.x509_dn_uuid }

        it 'returns FormResponse with success: false' do
          expect(form.submit.to_h).to eq(
            success: false,
            error_details: { piv_cac: { already_associated: true } },
            multi_factor_auth_method: 'piv_cac',
            key_id: 'foo',
          )

          expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq false
          expect(form.error_type).to eq 'piv_cac.already_associated'
        end
      end

      context 'and the same card is suspended for the user’s account recovery' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }
        let(:x509_dn_uuid) { user.piv_cac_configurations.first.x509_dn_uuid }

        before do
          recovery_request = create(
            :account_recovery_request,
            :replacement_mfa_pending,
            user: user,
          )
          user.piv_cac_configurations.update_all(
            account_recovery_request_id: recovery_request.id,
          )
        end

        it 'releases the suspended card so the same one can be re-enrolled' do
          expect(form.submit.to_h).to eq(
            success: true,
            multi_factor_auth_method: 'piv_cac',
            key_id: 'foo',
          )

          configurations = user.reload.piv_cac_configurations
          expect(configurations.count).to eq(1)
          expect(configurations.first.x509_dn_uuid).to eq(x509_dn_uuid)
          expect(configurations.first).to_not be_suspended_for_account_recovery
        end

        context 'and the suspended card uses the same nickname' do
          let(:form) do
            described_class.new(user: user, token: token, nonce: nonce, name: suspended_name)
          end
          let(:suspended_name) { user.piv_cac_configurations.first.name }

          it 'reuses the nickname' do
            expect(form.submit).to be_success
            expect(user.reload.piv_cac_configurations.map(&:name)).to eq([suspended_name])
          end
        end
      end

      context 'and the same card is associated but not suspended' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }
        let(:x509_dn_uuid) { user.piv_cac_configurations.first.x509_dn_uuid }

        it 'still reports the card as already associated' do
          expect(form.submit.to_h).to include(
            success: false,
            error_details: { piv_cac: { already_associated: true } },
          )
          expect(user.reload.piv_cac_configurations.count).to eq(1)
        end
      end
    end

    context 'when token is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => nonce, 'key_id' => 'foo' }
      end

      it 'returns FormResponse with success: false' do
        expect(form.submit.to_h).to eq(
          success: false,
          error_details: { token: { bad: true } },
          multi_factor_auth_method: 'piv_cac',
          key_id: 'foo',
        )

        expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq false
        expect(form.error_type).to eq 'token.bad'
      end

      context 'and the user has a card suspended for account recovery' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

        before do
          recovery_request = create(
            :account_recovery_request,
            :replacement_mfa_pending,
            user: user,
          )
          user.piv_cac_configurations.update_all(
            account_recovery_request_id: recovery_request.id,
          )
        end

        it 'keeps the suspended card' do
          suspended = user.piv_cac_configurations.first

          expect(form.submit).to_not be_success
          expect(PivCacConfiguration.exists?(suspended.id)).to eq(true)
        end
      end
    end

    context 'when nonce is invalid' do
      let(:token) { 'bad-token' }
      let(:token_response) do
        { 'error' => 'token.bad', 'nonce' => bad_nonce, 'key_id' => 'foo' }
      end
      let(:bad_nonce) { nonce + 'X' }

      it 'returns FormResponse with success: false' do
        expect(form.submit.to_h).to eq(
          success: false,
          error_details: { token: { invalid: true } },
          multi_factor_auth_method: 'piv_cac',
          key_id: 'foo',
        )
        expect(form.error_type).to eq 'token.invalid'
      end
    end

    context 'when token is missing' do
      let(:token) {}

      it 'returns FormResponse with success: false' do
        expect(form.submit.to_h).to eq(
          success: false,
          error_details: { token: { blank: true } },
          multi_factor_auth_method: 'piv_cac',
          key_id: nil,
        )
        expect(TwoFactorAuthentication::PivCacPolicy.new(user.reload).enabled?).to eq false
      end
    end
  end
end
