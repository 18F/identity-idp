require 'rails_helper'

RSpec.describe Idv::UspsPresenter do
  let(:user) { create(:user) }
  let(:any_mail_sent?) { false }

  subject(:decorator) do
    described_class.new(user)
  end

  describe '#title' do
    context 'a letter has not been sent' do
      it 'provides text to send' do
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.verify')
        )
      end
    end

    context 'a letter has been sent' do
      it 'provides text to resend' do
        create_letter_send_event
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.resend')
        )
      end
    end
  end

  describe '#button' do
    context 'a letter has not been sent' do
      it 'provides text to send' do
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.send')
        )
      end
    end

    context 'a letter has been sent' do
      it 'provides text to resend' do
        create_letter_send_event
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.resend')
        )
      end
    end
  end

  describe '#cancel_path' do
    context 'when the user has a pending profile' do
      it 'returns the verify account path' do
        create(:profile, user: user, deactivation_reason: :verification_pending)
        expect(subject.cancel_path).to eq('/account/verify')
      end
    end

    context 'when the user does not have a pending profile' do
      it 'returns the idv cancel path' do
        expect(subject.cancel_path).to eq('/verify/cancel')
      end
    end
  end

  def create_letter_send_event
    create(:event, user_id: user.id, event_type: :usps_mail_sent)
  end
end
