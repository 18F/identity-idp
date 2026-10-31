require 'rails_helper'

RSpec.describe SiteKeys::RecoveryForm do
  let(:user) { create(:user) }
  let!(:created) { create_site_key(user, acknowledge: true) }
  let(:session) { {} }
  let(:vault) { SiteKeys::Vault.new(user: user.reload, user_session: session) }
  let(:code) { created.recovery_code }

  before { user.site_key.forget_password! }

  subject(:form) { described_class.new(vault:, code:) }

  describe '#submit' do
    context 'with the recovery code' do
      it 'succeeds and opens the key in the session' do
        expect(form.submit.success?).to eq(true)
        expect(vault.private_key).to eq(created.private_key)
      end

      it 'clears the code' do
        form.submit

        expect(form.code).to be_nil
      end
    end

    context 'with a wrong code' do
      let(:code) { SiteKeys::RecoveryCode.generate }

      it 'fails and leaves the key locked' do
        result = form.submit

        expect(result.success?).to eq(false)
        expect(result.to_h[:error_details]).to eq(code: { site_key_recovery_code: true })
        expect(vault.private_key).to be_nil
      end
    end

    context 'with a blank code' do
      let(:code) { '' }

      it 'fails' do
        expect(form.submit.to_h[:error_details]).to eq(code: { blank: true })
      end
    end

    context 'when the key cannot be decrypted for a transient reason' do
      before do
        allow_any_instance_of(SiteKeys::Cipher).to receive(:recover)
          .and_raise(Encryption::EncryptionError)
      end

      it 'fails without blaming the code' do
        expect(form.submit.to_h[:error_details])
          .to eq(code: { site_key_recovery_unavailable: true })
      end
    end
  end
end
