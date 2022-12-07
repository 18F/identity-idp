require 'rails_helper'

RSpec.describe Idv::GpoPresenter do
  let(:user) { create(:user) }

  subject(:decorator) do
    described_class.new(user, {})
  end

  describe '#title' do
    context 'a letter has not been sent' do
      it 'provides text to send' do
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.verify'),
        )
      end
    end

    context 'a letter has been sent' do
      before do
        allow(user).to receive(:pending_profile).and_return(true)
      end
      it 'provides text to resend' do
        create_letter_send_event

        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.resend'),
        )
      end
    end

    context 'the user has verified with GPO before, but is re-proofing' do
      let(:user) { user_verified_with_gpo }
      it 'provides text to send' do
        create_letter_send_event
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.verify'),
        )
      end
    end
  end

  describe '#button' do
    let(:user) { create(:user) }
    context 'a letter has not been sent' do
      it 'provides text to send' do
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.send'),
        )
      end
    end

    context 'a letter has been sent' do
      before do
        allow(user).to receive(:pending_profile).and_return(true)
      end
      it 'provides text to resend' do
        create_letter_send_event
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.resend'),
        )
      end
    end
  end

  describe '#fallback_back_path' do
    context 'when the user has a pending profile' do
      it 'returns the verify account path' do
        create(:profile, user: user, deactivation_reason: :gpo_verification_pending)
        expect(subject.fallback_back_path).to eq('/account/verify')
      end
    end

    context 'when the user does not have a pending profile' do
      it 'returns the idv phone path' do
        expect(subject.fallback_back_path).to eq('/verify/phone')
      end
    end
  end

  def create_letter_send_event
    device = create(:device, user: user)
    create(:event, user: user, device: device, event_type: :gpo_mail_sent)
  end

  def user_verified_with_gpo
    create(:user, :proofed_with_gpo)
  end
end
