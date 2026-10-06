require 'rails_helper'

RSpec.describe SiteKeys::RecoveryForm do
  let(:user) { create(:user) }
  let!(:created) do
    allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
    create_site_key_root(user)
  end
  let(:code) { created.recovery_code }

  subject(:form) { described_class.new(user:, code:) }

  before { user.site_key_root.forget_password! }

  describe '#submit' do
    context 'with the recovery code' do
      it 'succeeds and exposes the recovered root' do
        expect(form.submit.success?).to eq(true)
        expect(form.recovered_root).to eq(created.root)
      end

      it 'clears the code' do
        form.submit

        expect(form.code).to be_nil
      end
    end

    context 'with a wrong code' do
      let(:code) { SiteKeys::RecoveryCode.generate }

      it 'fails' do
        result = form.submit

        expect(result.success?).to eq(false)
        expect(result.to_h[:error_details]).to eq(code: { site_key_recovery_code: true })
      end
    end

    context 'with a blank code' do
      let(:code) { '' }

      it 'fails' do
        expect(form.submit.to_h[:error_details]).to eq(code: { blank: true })
      end
    end

    context 'when the root cannot be decrypted' do
      before do
        allow_any_instance_of(SiteKeys::RootCipher).to receive(:recover)
          .and_raise(Encryption::EncryptionError)
      end

      it 'fails without blaming the code' do
        expect(form.submit.to_h[:error_details])
          .to eq(code: { site_key_recovery_unavailable: true })
      end
    end
  end
end
