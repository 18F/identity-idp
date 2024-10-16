require 'rails_helper'

RSpec.describe Idv::ByMail::LetterRequestedEmailPresenter do
  include Rails.application.routes.url_helpers

  let(:service_provider) { create(:service_provider) }

  let(:profile) do
    create(
      :profile,
      :verify_by_mail_pending,
      initiating_service_provider: service_provider,
    )
  end

  let(:user) { profile.user }

  subject(:presenter) { described_class.new(current_user: user, url_options: {}) }

  context 'when there is no associated service provider' do
    let(:service_provider) { nil }

    describe '#sp_name' do
      it { expect(presenter.sp_name).to be_nil }
    end

    describe '#show_sp_contact_instructions?' do
      it { expect(presenter.show_sp_contact_instructions?).to eq(false) }
    end

    describe '#show_cta?' do
      it { expect(presenter.show_cta?).to eq(true) }
    end

    describe '#sign_in_url' do
      it { expect(presenter.sign_in_url).to eq(root_url) }
    end
  end

  context 'where there is a service provider' do
    context 'when the service provider has no return URL' do
      let(:service_provider) do
        create(
          :service_provider,
          return_to_sp_url: nil,
          friendly_name: 'My Awesome SP',
        )
      end

      describe '#sp_name' do
        it { expect(presenter.sp_name).to eq('My Awesome SP') }
      end

      describe '#show_sp_contact_instructions?' do
        it { expect(presenter.show_sp_contact_instructions?).to eq(true) }
      end

      describe '#show_cta?' do
        it { expect(presenter.show_cta?).to eq(false) }
      end

      describe '#sign_in_url' do
        it { expect(presenter.sign_in_url).to eq(nil) }
      end
    end

    context 'when the service provider does have a return URL' do
      let(:service_provider) do
        create(
          :service_provider,
          return_to_sp_url: 'https://www.example.com',
          friendly_name: 'My Awesome SP',
        )
      end

      describe '#sp_name' do
        it { expect(presenter.sp_name).to eq('My Awesome SP') }
      end

      describe '#show_sp_contact_instructions?' do
        it { expect(presenter.show_sp_contact_instructions?).to eq(true) }
      end

      describe '#show_cta?' do
        it { expect(presenter.show_cta?).to eq(true) }
      end

      describe '#sign_in_url' do
        it { expect(presenter.sign_in_url).to eq('https://www.example.com') }
      end
    end
  end
end
