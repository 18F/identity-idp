require 'rails_helper'

RSpec.describe VerifyPersonalKeyForm do
  let(:user) { create(:user) }

  let!(:profile) do
    create(:profile, :active, :password_reset, user: user, pii: { ssn: '123456789' })
  end

  subject(:form) do
    VerifyPersonalKeyForm.new(
      user: user,
      personal_key: personal_key,
    )
  end

  describe '#submit' do
    describe 'with the correct personal key' do
      let(:personal_key) { profile.personal_key }

      it 'has a successful response' do
        result = form.submit
        expect(result).to be_success
      end

      it 'exposes the decrypted_pii as a separate attribute' do
        form.submit
        expect(form.decrypted_pii_json).to be_present
        expect(JSON.parse(form.decrypted_pii_json, symbolize_names: true)).
          to include(ssn: '123456789')
      end
    end

    describe 'with an incorrect personal key' do
      let(:personal_key) { 'asdasda' }

      it 'is an unsuccessful response' do
        result = form.submit
        expect(result).to_not be_success
      end

      it 'resets sensitive fields' do
        expect { form.submit }.to(change { form.personal_key }.to(nil))
      end
    end
  end
end
