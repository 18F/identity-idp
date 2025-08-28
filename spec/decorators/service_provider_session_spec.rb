require 'rails_helper'

RSpec.describe ServiceProviderSession do
  let(:view_context) { ActionController::Base.new.view_context }
  subject(:session_decorator) do
    ServiceProviderSession.new(
      sp: sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: service_provider_request,
    )
  end
  let(:sp) { build_stubbed(:service_provider) }
  let(:sp_session) { { acr_values: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF } }
  let(:service_provider_request) { ServiceProviderRequest.new }
  let(:sp_name) { subject.sp_name }
  let(:sp_create_link) { '/sign_up/enter_email' }

  before do
    allow(view_context).to receive(:sign_up_email_path)
      .and_return('/sign_up/enter_email')
  end

  it 'has the same public API as NullServiceProviderSession' do
    NullServiceProviderSession.public_instance_methods.each do |method|
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

  describe '#sp_alert' do
    context 'sp has custom alert' do
      it 'uses the custom template' do
        expect(subject.sp_alert('sign_in'))
          .to eq "<strong>custom sign in help text for #{sp.friendly_name}</strong>"
      end
    end

    context 'sp does not have a custom alert' do
      let(:sp) { build_stubbed(:service_provider_without_help_text) }

      it 'returns nil' do
        expect(subject.sp_alert('sign_in'))
          .to be_nil
      end
    end

    context 'sp has a nil custom alert' do
      let(:sp) { build(:service_provider, help_text: nil) }

      it 'returns nil' do
        expect(subject.sp_alert('sign_in'))
          .to be_nil
      end
    end

    context 'sp has a blank custom alert' do
      let(:sp) { build_stubbed(:service_provider, :with_blank_help_text) }

      it 'returns nil' do
        expect(subject.sp_alert('sign_in'))
          .to be_nil
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
      subject = ServiceProviderSession.new(
        sp: sp,
        view_context: view_context,
        sp_session: {},
        service_provider_request: ServiceProviderRequestProxy.new,
      )
      expect(subject.sp_name).to eq sp.agency.name
      expect(subject.sp_name).to_not be_nil
    end
  end

  describe '#cancel_link_url' do
    subject(:decorator) do
      ServiceProviderSession.new(
        sp: sp,
        view_context: view_context,
        sp_session: { request_id: 'foo' },
        service_provider_request: ServiceProviderRequestProxy.new,
      )
    end

    before do
      allow(view_context).to receive(:new_user_session_url)
        .and_return('https://www.example.com/')
    end

    it 'returns view_context.new_user_session_url' do
      expect(decorator.cancel_link_url)
        .to eq 'https://www.example.com/'
    end
  end

  describe '#requested_more_recent_verification?' do
    let(:verified_within) { nil }
    let(:user) { create(:user) }
    let(:client_id) { sp.issuer }

    before do
      allow(view_context).to receive(:current_user).and_return(user)
      allow(IdentityConfig.store).to receive(
        :allowed_verified_within_providers,
      ) { [client_id] }
      allow(session_decorator).to receive(:authorize_form)
        .and_return(OpenidConnectAuthorizeForm.new(verified_within:, client_id:))
    end

    subject(:requested_more_recent_verification?) do
      session_decorator.requested_more_recent_verification?
    end

    context 'issuer is allowed to use verified_within' do
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

    context 'issuer is not allowed to use verified_within' do
      let(:client_id) { 'different id' }

      it 'is false with no verified_within param' do
        expect(requested_more_recent_verification?).to eq(false)
      end

      context 'with a valid verified_within' do
        let(:verified_within) { '45d' }

        it 'is false' do
          expect(requested_more_recent_verification?).to eq(false)
        end

        context 'the verified_at is older than the verified_at' do
          before do
            create(:profile, :active, user: user, verified_at: 60.days.ago)
          end

          it 'is false' do
            expect(requested_more_recent_verification?).to eq(false)
          end
        end
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

  describe '#attempt_api_session_id' do
    let(:service_provider_request) { ServiceProviderRequest.new(url:) }

    context 'without an an attempts_api_session_id in the request_url_params' do
      let(:url) { 'https://example.com/auth?param0=p0&param1=p1&param2=p2' }

      it 'returns nil' do
        expect(subject.attempts_api_session_id).to be nil
      end

      context 'with a tid in the request_url_params' do
        let(:url) { 'https://example.com/auth?param0=p0&param1=p1&tid=abc123' }

        it 'returns the value in the tid param' do
          expect(subject.attempts_api_session_id).to eq 'abc123'
        end
      end
    end

    context 'with an attempts_api_session_id in the request_url_params' do
      let(:url) { 'https://example.com/auth?attempts_api_session_id=abc123&param1=p1&param2=p2' }

      it 'returns the value in the attempts_api_session_id param' do
        expect(subject.attempts_api_session_id).to eq 'abc123'
      end

      context 'with a tid in the request_url_params' do
        let(:url) { 'https://example.com/auth?param0=p0&tid=abc123&attempts_api_session_id=not-tid' }

        it 'returns the value in attempts_api_session_id param' do
          expect(subject.attempts_api_session_id).to eq 'not-tid'
        end
      end
    end
  end

  describe '#attempt_api_request_uri' do
    let(:service_provider_request) { ServiceProviderRequest.new(url:) }
    let(:redirect_uri) { 'http://example.com/redirect' }

    context 'with a redirect_uri in the request_url_params' do
      let(:url) { "https://example.com/auth?param0=p0&redirect_uri=#{redirect_uri}&param2=p2" }

      it 'returns the redirect_uri' do
        expect(subject.attempts_api_request_uri).to eq redirect_uri
      end
    end

    context 'with no redirect uri in the request_url_params' do
      context 'with a SAML integration' do
        let(:sp) { build_stubbed(:service_provider, acs_url: redirect_uri) }

        let(:url) { 'https://example.com/auth?param0=p0' }

        it 'returns the redirect_uri' do
          expect(subject.attempts_api_request_uri).to eq redirect_uri
        end
      end
    end
  end
end
