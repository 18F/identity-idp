require 'rails_helper'

RSpec.describe UserPivCacLoginForm do
  let(:user) { create(:user) }
  let(:piv_cac_configuration) do
    create(:piv_cac_configuration, user_id: user.id, x509_dn_uuid: 'random-uuid-for-x509-subject')
  end
  let(:nonce) { 'nonce' }
  let(:piv_cac_required) { false }
  let(:form) { described_class.new(token: token, nonce: nonce, piv_cac_required: piv_cac_required) }

  describe '#submit' do
    before(:each) do
      allow(PivCacService).to receive(:decode_token).with(token) { token_response }
    end

    context 'when token is valid' do
      let(:token) { 'good-token' }

      let(:token_response) do
        {
          'uuid' => piv_cac_configuration.x509_dn_uuid,
          'subject' => 'x509-subject',
          'nonce' => nonce,
          'key_id' => 'foo',
        }
      end

      it 'returns FormResponse with success: true' do
        expect(form.submit.to_h).to eq(
          success: true,
          key_id: 'foo',
        )
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
          key_id: 'foo',
        )
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
        expect(form.submit.to_h).to eq(
          success: false,
          error_details: { token: { invalid: true } },
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
          key_id: nil,
        )
      end
    end
  end

  describe '#valid_token?' do
    context 'when token is blank' do
      let(:token) { '' }

      it 'returns false' do
        expect(form.valid_token?).to eq false
      end
    end
  end
end
