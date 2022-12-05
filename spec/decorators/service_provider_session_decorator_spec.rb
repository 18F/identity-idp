require 'rails_helper'

RSpec.describe ServiceProviderSessionDecorator do
  let(:view_context) { ActionController::Base.new.view_context }
  subject(:session_decorator) do
    ServiceProviderSessionDecorator.new(
      sp: sp,
      view_context: view_context,
      sp_session: {},
      service_provider_request: service_provider_request,
    )
  end
  let(:sp) { build_stubbed(:service_provider) }
  let(:service_provider_request) { ServiceProviderRequest.new }
  let(:sp_name) { subject.sp_name }
  let(:sp_create_link) { '/sign_up/enter_email' }

  before do
    allow(view_context).to receive(:sign_up_email_path).
      and_return('/sign_up/enter_email')
  end

  it 'has the same public API as SessionDecorator' do
    SessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method),
      ).to be(true), "expected #{described_class} to have ##{method}"
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
        I18n.t('idv.messages.select_verification_with_sp', sp_name: sp_name),
      )
    end
  end

  describe '#custom_alert' do
    context 'sp has custom alert' do
      it 'uses the custom template' do
        expect(subject.custom_alert('sign_in')).
          to eq "<b>custom sign in help text for #{sp.friendly_name}</b>"
      end
    end

    context 'sp does not have a custom alert' do
      let(:sp) { build_stubbed(:service_provider_without_help_text) }

      it 'returns nil' do
        expect(subject.custom_alert('sign_in')).
          to be_nil
      end
    end

    context 'sp has a nil custom alert' do
      let(:sp) { build(:service_provider, help_text: nil) }

      it 'returns nil' do
        expect(subject.custom_alert('sign_in')).
          to be_nil
      end
    end

    context 'sp has a blank custom alert' do
      let(:sp) { build_stubbed(:service_provider, :with_blank_help_text) }

      it 'returns nil' do
        expect(subject.custom_alert('sign_in')).
          to be_nil
      end
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
        service_provider_request: ServiceProviderRequestProxy.new,
      )
      expect(subject.sp_name).to eq sp.agency.name
      expect(subject.sp_name).to_not be_nil
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
          service_provider_request: ServiceProviderRequestProxy.new,
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
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo).to eq 'generic.svg'
      end
    end
  end

  describe '#sp_logo_url' do
    context 'service provider has a logo' do
      it 'returns the logo' do
        sp_logo = '18f.svg'
        sp = build_stubbed(:service_provider, logo: sp_logo)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo_url).to match(%r{sp-logos/18f-[0-9a-f]+\.svg$})
      end
    end

    context 'service provider does not have a logo' do
      it 'returns the default logo' do
        sp = build_stubbed(:service_provider, logo: nil)

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo_url).to match(%r{/sp-logos/generic-.+\.svg})
      end
    end

    context 'service provider has a poorly configured logo' do
      it 'does not raise an exception' do
        sp = build_stubbed(:service_provider, logo: 'abc')

        subject = ServiceProviderSessionDecorator.new(
          sp: sp,
          view_context: view_context,
          sp_session: {},
          service_provider_request: ServiceProviderRequestProxy.new,
        )

        expect(subject.sp_logo_url).is_a? String
      end
    end
  end

  describe '#cancel_link_url' do
    subject(:decorator) do
      ServiceProviderSessionDecorator.new(
        sp: sp,
        view_context: view_context,
        sp_session: { request_id: 'foo' },
        service_provider_request: ServiceProviderRequestProxy.new,
      )
    end

    before do
      allow(view_context).to receive(:new_user_session_url).
        and_return('https://www.example.com/')
    end

    it 'returns view_context.new_user_session_url' do
      expect(decorator.cancel_link_url).
        to eq 'https://www.example.com/'
    end
  end

  describe '#mfa_expiration_interval' do
    context 'with an AAL2 sp' do
      before do
        allow(sp).to receive(:default_aal).and_return(2)
      end

      it { expect(subject.mfa_expiration_interval).to eq(12.hours) }
    end

    context 'with an IAL2 sp' do
      before do
        allow(sp).to receive(:ial).and_return(2)
      end

      it { expect(subject.mfa_expiration_interval).to eq(12.hours) }
    end

    context 'with an sp that is not AAL2 or IAL2' do
      it { expect(subject.mfa_expiration_interval).to eq(30.days) }
    end
  end

  describe '#requested_more_recent_verification?' do
    let(:verified_within) { nil }
    let(:user) { create(:user) }

    before do
      allow(view_context).to receive(:current_user).and_return(user)
      allow(session_decorator).to receive(:authorize_form).
        and_return(OpenidConnectAuthorizeForm.new(verified_within: verified_within))
    end

    subject(:requested_more_recent_verification?) do
      session_decorator.requested_more_recent_verification?
    end

    it 'is false with no verified_within param' do
      expect(requested_more_recent_verification?).to eq(false)
    end

    context 'with a valid verified_within' do
      let(:verified_within) { '45d' }

      it 'is true if the user does not have an activated profile' do
        expect(requested_more_recent_verification?).to eq(true)
      end

      context 'the verified_at is newer than the verified_within ' do
        before do
          create(:profile, :active, user: user, verified_at: 15.days.ago)
        end

        it 'is false' do
          expect(requested_more_recent_verification?).to eq(false)
        end
      end

      context 'the verified_at is older than the verified_at' do
        before do
          create(:profile, :active, user: user, verified_at: 60.days.ago)
        end

        it 'is true' do
          expect(requested_more_recent_verification?).to eq(true)
        end
      end
    end
  end

  describe '#irs_attempts_api_session_id' do
    context 'with a irs_attempts_api_session_id on the request url' do
      let(:service_provider_request) do
        url = 'https://example.com/auth?irs_attempts_api_session_id=123abc'
        ServiceProviderRequest.new(url: url)
      end

      it 'returns the value of irs_attempts_api_session_id' do
        expect(subject.irs_attempts_api_session_id).to eq('123abc')
      end
    end

    context 'with a tid on the request url' do
      let(:service_provider_request) do
        url = 'https://example.com/auth?tid=123abc'
        ServiceProviderRequest.new(url: url)
      end

      it 'returns the value of irs_attempts_api_session_id' do
        expect(subject.irs_attempts_api_session_id).to eq('123abc')
      end
    end

    context 'without a irs_attempts_api_session_id or tid on the request url' do
      let(:service_provider_request) { ServiceProviderRequest.new }

      it 'returns nil' do
        expect(subject.irs_attempts_api_session_id).to be_nil
      end
    end
  end

  describe '#request_url_params' do
    context 'without url params' do
      it 'returns an empty hash' do
        expect(subject.request_url_params).to eq({})
      end
    end

    context 'with url params' do
      let(:service_provider_request) do
        url = 'https://example.com/auth?param0=p0&param1=p1&param2=p2'
        ServiceProviderRequest.new(url: url)
      end
      let(:expected_hash) { { 'param0' => 'p0', 'param1' => 'p1', 'param2' => 'p2' } }

      it 'returns the url parameters' do
        expect(subject.request_url_params).to eq(expected_hash)
      end
    end
  end
end
