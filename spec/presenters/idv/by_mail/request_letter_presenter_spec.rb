require 'rails_helper'

RSpec.describe Idv::ByMail::RequestLetterPresenter do
  include Rails.application.routes.url_helpers

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
        allow(user).to receive(:gpo_verification_pending_profile).and_return(true)
      end
      it 'provides text to resend' do
        create_letter_send_event

        expect(subject.title).to eq(
          I18n.t('idv.gpo.request_another_letter.title'),
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
        allow(user).to receive(:gpo_verification_pending_profile).and_return(true)
      end
      it 'provides text to resend' do
        create_letter_send_event
        expect(subject.button).to eq(
          I18n.t('idv.gpo.request_another_letter.button'),
        )
      end
    end
  end

  describe '#fallback_back_path' do
    context 'when the user has a pending profile' do
      it 'returns the verify account path' do
        create(:profile, user:, gpo_verification_pending_at: 1.day.ago)
        expect(subject.fallback_back_path).to eq(idv_verify_by_mail_enter_code_path)
      end
    end

    context 'when the user does not have a pending profile' do
      it 'returns the idv phone path' do
        expect(subject.fallback_back_path).to eq(idv_phone_path)
      end
    end
  end

  def create_letter_send_event
    device = create(:device, user:)
    create(:event, user:, device:, event_type: :gpo_mail_sent)
  end

  def user_verified_with_gpo
    create(:user, :proofed_with_gpo)
  end
end
