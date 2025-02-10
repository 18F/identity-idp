require 'rails_helper'

RSpec.describe Idv::InPerson::VerificationResultsEmailPresenter do
  include Rails.application.routes.url_helpers

  let(:visited_location_name) { 'ACQUAINTANCESHIP' }
  let(:status_updated_at) { described_class::USPS_SERVER_TIMEZONE.parse('2022-07-14T00:00:00Z') }
  let(:sp) { nil }
  let(:current_address_matches_id) { true }
  let(:enrollment) do
    create(
      :in_person_enrollment,
      :pending,
      service_provider: sp,
      selected_location_details: { name: 'FRIENDSHIP' },
      current_address_matches_id: current_address_matches_id,
    )
  end

  subject(:presenter) do
    described_class.new(
      enrollment: enrollment, url_options: {},
      visited_location_name: visited_location_name
    )
  end

  describe 'visited_location_name' do
    it 'returns the location that USPS reports the user visited for their proofing attempt' do
      expect(presenter.visited_location_name).to eq(visited_location_name)
    end
  end

  describe '#formatted_verified_date' do
    before do
      enrollment.update(status_updated_at: DateTime.new(2024, 7, 5))
    end

    [
      ['English', :en, 'July 4, 2024'],
      ['Spanish', :es, '4 de julio de 2024'],
      ['French', :fr, '4 juillet 2024'],
      ['Chinese', :zh, '2024年7月4日'],
    ].each do |language, locale, expected|
      context "when locale is #{language}" do
        before do
          I18n.locale = locale
        end

        it "returns the formatted due date in #{language}" do
          expect(presenter.formatted_verified_date).to eq(expected)
        end
      end
    end
  end

  describe '#service_provider' do
    it 'returns service provider associated with enrollment' do
      expect(presenter.service_provider).to eq(enrollment.service_provider)
    end
  end

  describe '#service_provider_or_app_name' do
    context 'without service provider' do
      let(:sp) { nil }

      it 'returns app name' do
        expect(presenter.service_provider_or_app_name).to eq(APP_NAME)
      end
    end

    context 'with service provider' do
      let(:sp) { create(:service_provider) }

      it 'returns friendly name of service provider' do
        expect(presenter.service_provider_or_app_name).to eq(sp.friendly_name)
      end
    end
  end

  describe '#service_provider_homepage_url' do
    context 'without service provider' do
      let(:sp) { nil }

      it 'returns nil' do
        expect(presenter.service_provider_homepage_url).to eq(nil)
      end
    end

    context 'with service provider' do
      let(:sp_url) { 'https://service.provider.gov' }
      let(:sp) { create(:service_provider, return_to_sp_url: sp_url) }

      it 'returns SP homepage url' do
        expect(presenter.service_provider_homepage_url).to eq(sp_url)
      end
    end
  end

  describe '#show_cta?' do
    context 'without service provider' do
      let(:sp) { nil }

      it { expect(presenter.show_cta?).to eq(true) }
    end

    context 'with service provider' do
      let(:homepage_url) { nil }
      let(:sp) { create(:service_provider) }

      before do
        resolver = instance_double(SpReturnUrlResolver)
        allow(resolver).to receive(:homepage_url).and_return(homepage_url)
        allow(presenter).to receive(:sp_return_url_resolver).and_return(resolver)
      end

      context 'without homepage_url' do
        let(:homepage_url) { nil }

        it { expect(presenter.show_cta?).to eq(false) }
      end

      context 'with homepage_url' do
        let(:homepage_url) { 'https://example.com' }

        it { expect(presenter.show_cta?).to eq(true) }
      end
    end
  end

  describe '#sign_in_url' do
    context 'without service provider' do
      let(:sp) { nil }

      it 'returns root url' do
        expect(presenter.sign_in_url).to eq(root_url)
      end
    end

    context 'with service provider' do
      let(:homepage_url) { nil }
      let(:sp) { create(:service_provider) }

      before do
        resolver = instance_double(SpReturnUrlResolver)
        allow(resolver).to receive(:homepage_url).and_return(homepage_url)
        allow(SpReturnUrlResolver).to receive(:new).with(service_provider: sp).and_return(resolver)
      end

      context 'without homepage_url' do
        let(:homepage_url) { nil }

        it 'returns root url' do
          expect(presenter.sign_in_url).to eq(root_url)
        end
      end

      context 'with homepage_url' do
        let(:homepage_url) { 'https://example.com' }

        it 'returns homepage url' do
          expect(presenter.sign_in_url).to eq(homepage_url)
        end
      end
    end
  end

  describe '#service_provider_homepage_url' do
    context 'without service provider' do
      let(:sp) { nil }

      it 'returns nil' do
        expect(presenter.service_provider_homepage_url).to be_nil
      end
    end

    context 'with service provider' do
      let(:homepage_url) { nil }
      let(:sp) { create(:service_provider) }

      before do
        resolver = instance_double(SpReturnUrlResolver)
        allow(resolver).to receive(:homepage_url).and_return(homepage_url)
        allow(SpReturnUrlResolver).to receive(:new).with(service_provider: sp).and_return(resolver)
      end

      context 'without homepage_url' do
        let(:homepage_url) { nil }

        it 'returns root url' do
          expect(presenter.service_provider_homepage_url).to be_nil
        end
      end

      context 'with homepage_url' do
        let(:homepage_url) { 'https://example.com' }

        it 'returns homepage url' do
          expect(presenter.service_provider_homepage_url).to eq(homepage_url)
        end
      end
    end
  end
end
