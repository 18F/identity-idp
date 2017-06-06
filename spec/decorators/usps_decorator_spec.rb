require 'rails_helper'

RSpec.describe UspsDecorator do
  subject(:decorator) do
    user = create(
      :user,
      :signed_up,
      profiles: [build(:profile, :active, :verified, pii: { first_name: 'Jane' })]
    )

    idv_session = Idv::Session.new({}, user)
    UspsDecorator.new(idv_session)
  end

  describe '#title' do
    context 'a letter has not been sent' do
      let(:idv_session) { subject.idv_session }

      it 'provides text to send' do
        subject.idv_session.address_verification_mechanism = nil
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.verify')
        )
      end
    end

    context 'a letter has been sent' do
      it 'provides text to resend' do
        subject.idv_session.address_verification_mechanism = 'usps'
        expect(subject.title).to eq(
          I18n.t('idv.titles.mail.resend')
        )
      end
    end
  end

  describe '#button' do
    context 'a letter has not been sent' do
      it 'provides text to send' do
        subject.idv_session.address_verification_mechanism = nil
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.send')
        )
      end
    end

    context 'a letter has been sent' do
      it 'provides text to resend' do
        subject.idv_session.address_verification_mechanism = 'usps'
        expect(subject.button).to eq(
          I18n.t('idv.buttons.mail.resend')
        )
      end
    end
  end
end
