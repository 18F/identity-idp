require 'rails_helper'

RSpec.describe ServiceProviderSessionDecorator do
  let(:view_context) { ActionController::Base.new.view_context }
  subject do
    ServiceProviderSessionDecorator.new(
      sp: sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: ServiceProviderRequest.new
    )
  end
  let(:sp) { build_stubbed(:service_provider) }
  let(:sp_name) { subject.sp_name }

  it 'has the same public API as SessionDecorator' do
    SessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method)
      ).to be(true), "expected #{described_class} to have ##{method}"
    end
  end

  describe '#return_to_service_provider_partial' do
    it 'returns the correct partial' do
      expect(subject.return_to_service_provider_partial).to eq(
        'devise/sessions/return_to_service_provider'
      )
    end
  end

  describe '#nav_partial' do
    it 'returns the correct partial' do
      expect(subject.nav_partial).to eq 'shared/nav_branded'
    end
  end

  describe '#new_session_heading' do
    it 'returns the correct string' do
      expect(subject.new_session_heading).to eq I18n.t('headings.sign_in_with_sp', sp: sp_name)
    end
  end

  describe '#verification_method_choice' do
    it 'returns the correct string' do
      expect(subject.verification_method_choice).to eq(
        I18n.t('idv.messages.select_verification_with_sp', sp_name: sp_name)
      )
    end
  end

  describe '#sp_name' do
    it 'returns the SP friendly name if present' do
      expect(subject.sp_name).to eq sp.friendly_name
      expect(subject.sp_name).to_not be_nil
    end

    it 'returns the agency name if friendly name is not present' do
      sp = build_stubbed(:service_provider, friendly_name: nil)
      subject = ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new
      )
      expect(subject.sp_name).to eq sp.agency
      expect(subject.sp_name).to_not be_nil
    end
  end

  describe '#sp_agency' do
    it 'returns the SP agency if present' do
      expect(subject.sp_agency).to eq sp.agency
      expect(subject.sp_agency).to_not be_nil
    end

    it 'returns the friendly name if the agency is not present' do
      sp = build_stubbed(:service_provider, friendly_name: 'friend', agency: nil)
      subject = ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequest.new
      )
      expect(subject.sp_agency).to eq sp.friendly_name
      expect(subject.sp_agency).to_not be_nil
    end
  end

  describe '#sp_logo' do
    context 'service provider has a logo' do
      it 'returns the logo' do
        sp_logo = 'real_logo.svg'
        sp = build_stubbed(:service_provider, logo: sp_logo)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequest.new
        )

        expect(subject.sp_logo).to eq sp_logo
      end
    end

    context 'service provider does not have a logo' do
      it 'returns the default logo' do
        sp = build_stubbed(:service_provider, logo: nil)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequest.new
        )

        expect(subject.sp_logo).to eq 'generic.svg'
      end
    end
  end

  describe '#cancel_link_url' do
    subject(:decorator) do
      ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: { request_id: 'foo' },
        service_provider_request: ServiceProviderRequest.new
      )
    end

    before do
      allow(view_context).to receive(:sign_up_start_url).
        and_return('https://www.example.com/sign_up/start')
    end

    it 'returns view_context.sign_up_start_url' do
      expect(decorator.cancel_link_url).
        to eq 'https://www.example.com/sign_up/start'
    end
  end
end
