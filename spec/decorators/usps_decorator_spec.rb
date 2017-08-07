require 'rails_helper'

RSpec.describe UspsDecorator do
  let(:user) { create(:user) }
  subject(:decorator) do
    usps_mail_service = Idv::UspsMail.new(user)
    UspsDecorator.new(usps_mail_service)
  end

  describe '#title' do
    context 'a letter has not been sent' do
      it 'provides text to send' do
        allow(subject.usps_mail_service).to receive(:any_mail_sent?).and_return(false)
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.verify')
        )
      end
    end

    context 'a letter has been sent' do
      it 'provides text to resend' do
        allow(subject.usps_mail_service).to receive(:any_mail_sent?).and_return(true)
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.resend')
        )
      end
    end
  end

  describe '#button' do
    context 'a letter has not been sent' do
      it 'provides text to send' do
        allow(subject.usps_mail_service).to receive(:any_mail_sent?).and_return(false)
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.send')
        )
      end
    end

    context 'a letter has been sent' do
      it 'provides text to resend' do
        allow(subject.usps_mail_service).to receive(:any_mail_sent?).and_return(true)
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.resend')
        )
      end
    end
  end
end
