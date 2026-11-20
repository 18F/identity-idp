require 'rails_helper'

RSpec.describe 'accounts/_identity_verification.html.erb' do
  let(:acr_values) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }
  let(:sp_name) { nil }
  let(:authn_context) do
    AuthnContextResolver.new(
      user:,
      service_provider: nil,
      acr_values:,
    ).result
  end
  let(:user) { build(:user) }
  subject(:rendered) { render partial: 'accounts/identity_verification' }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    @presenter = AccountShowPresenter.new(
      decrypted_pii: nil,
      sp_session_request_url: nil,
      authn_context:,
      sp_name:,
      user:,
      locked_for_session: false,
    )
  end

  context 'with user pending gpo verification' do
    let(:gpo_sp_name) { 'GPO SP' }
    let(:gpo_sp_issuer) { 'urn:gov:gsa:openidconnect:sp:gpo_sp' }
    let(:gpo_sp) { create(:service_provider, issuer: gpo_sp_issuer, friendly_name: gpo_sp_name) }
    let(:user) { create(:user, :with_pending_gpo_profile) }

    before do
      gpo_sp
      user.pending_profile.update(initiating_service_provider_issuer: gpo_sp_issuer)
    end

    it 'references initiating sp with prompt to finish verifying their identity' do
      expect(rendered).to have_content(
        strip_tags(t('account.index.verification.finish_verifying_html', sp_name: gpo_sp_name)),
      )
    end

    it 'does not render alert to connect to IdV SP' do
      expect(rendered).to_not have_content(
        strip_tags(t('account.index.verification.connect_idv_account.intro')),
      )
    end
  end

  context 'with user pending ipp verification' do
    let(:ipp_sp_name) { 'IPP SP' }
    let(:ipp_sp_issuer) { 'urn:gov:gsa:openidconnect:sp:ipp_sp' }
    let(:ipp_sp) { create(:service_provider, issuer: ipp_sp_issuer, friendly_name: ipp_sp_name) }
    let(:user) { build(:user, :with_pending_in_person_enrollment) }

    before do
      ipp_sp
      user.pending_profile.update(initiating_service_provider_issuer: ipp_sp_issuer)
    end

    it 'references initiating sp with prompt to finish verifying their identity' do
      expect(rendered).to have_content(
        strip_tags(t('account.index.verification.finish_verifying_html', sp_name: ipp_sp_name)),
      )
    end

    it 'does not render alert to connect to IdV SP' do
      expect(rendered).to_not have_content(
        strip_tags(t('account.index.verification.connect_idv_account.intro')),
      )
    end
  end

  context 'with partner requesting non-facial match verification' do
    let(:sp_name) { 'Example SP' }
    let(:acr_values) do
      [
        Saml::Idp::Constants::IAL_VERIFIED_ACR,
        Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      ].join(' ')
    end

    context 'with unproofed user' do
      let(:user) { build(:user) }

      it 'shows unverified badge' do
        expect(rendered).to have_content(t('account.index.verification.unverified_badge'))
      end

      it 'shows warning alert instructing user to complete identity verification' do
        expect(rendered).to have_css('.usa-alert.usa-alert--warning')
        expect(rendered).to have_content(
          strip_tags(t('account.index.verification.finish_verifying_html', sp_name:)),
        )
        expect(rendered).to have_link(t('account.index.verification.continue_idv'), href: idv_path)
      end
    end

    context 'with user pending ipp verification' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      it 'shows pending badge' do
        expect(rendered).to have_content(t('account.index.verification.pending_badge'))
      end

      it 'shows content explaining that the user needs to finish verifying their identity' do
        expect(rendered).to have_content(
          strip_tags(t('account.index.verification.finish_verifying_html', sp_name:)),
        )
        expect(rendered).to have_link(
          t('account.index.verification.learn_more_link'),
          href: help_center_redirect_path(
            category: 'verify-your-identity',
            article: 'overview',
            flow: :account_show,
            location: :idv,
          ),
        )
      end

      it 'shows info alert instructing user to go to the post office to complete verification' do
        expect(rendered).to have_css('.usa-alert.usa-alert--info')
        expect(rendered).to have_content(
          strip_tags(
            t(
              'account.index.verification.in_person_instructions_html',
              deadline: @presenter.formatted_ipp_due_date,
            ),
          ),
        )
        expect(rendered).to have_link(
          t('account.index.verification.show_bar_code', app_name: APP_NAME),
          href: idv_in_person_ready_to_verify_url,
        )
      end
    end

    context 'with user pending gpo verification' do
      let(:user) { create(:user, :with_pending_gpo_profile) }

      it 'shows pending badge' do
        expect(rendered).to have_content(t('account.index.verification.pending_badge'))
      end

      it 'shows content explaining that the user needs to finish verifying their identity' do
        expect(rendered).to have_content(
          strip_tags(t('account.index.verification.finish_verifying_html', sp_name:)),
        )
        expect(rendered).to have_link(
          t('account.index.verification.learn_more_link'),
          href: help_center_redirect_path(
            category: 'verify-your-identity',
            article: 'overview',
            flow: :account_show,
            location: :idv,
          ),
        )
      end

      it 'shows info alert instructing user to enter their gpo verification code' do
        expect(rendered).to have_css('.usa-alert.usa-alert--info')
        expect(rendered).to have_content(t('account.index.verification.instructions'))
        expect(rendered).to have_link(
          t('account.index.verification.reactivate_button'),
          href: idv_verify_by_mail_enter_code_path,
        )
      end
    end

    context 'with non-facial match proofed user' do
      let(:user) { build(:user, :proofed) }

      it 'shows verified badge' do
        expect(rendered).to have_content(t('account.index.verification.verified_badge'))
      end

      it 'shows content confirming verified identity' do
        expect(rendered).to have_content(
          strip_tags(
            t('account.index.verification.you_verified_your_identity_html', sp_name: APP_NAME),
          ),
        )
        expect(rendered).to have_link(
          t('account.index.verification.learn_more_link'),
          href: help_center_redirect_path(
            category: 'verify-your-identity',
            article: 'overview',
            flow: :account_show,
            location: :idv,
          ),
        )
      end

      it 'renders pii' do
        expect(rendered).to render_template(partial: 'accounts/_pii')
      end

      context 'with initiating sp for active profile' do
        let(:sp_name) { 'Example SP' }
        let(:sp_issuer) { 'urn:gov:gsa:openidconnect:sp:example_sp' }
        let(:sp) { create(:service_provider, issuer: sp_issuer, friendly_name: sp_name) }

        before do
          sp
          user.active_profile.update(initiating_service_provider_issuer: sp_issuer)
        end

        it 'shows content confirming verified identity for initiating sp' do
          expect(rendered).to have_content(
            strip_tags(
              t('account.index.verification.you_verified_your_identity_html', sp_name:),
            ),
          )
        end
      end
    end
  end

  context 'with partner requesting facial match verification' do
    let(:sp_name) { 'Example SP' }
    let(:acr_values) do
      [
        Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
        Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
      ].join(' ')
    end

    context 'with unproofed user' do
      let(:user) { build(:user) }

      it 'shows unverified badge' do
        expect(rendered).to have_content(t('account.index.verification.unverified_badge'))
      end

      it 'shows warning alert instructing user to complete identity verification' do
        expect(rendered).to have_css('.usa-alert.usa-alert--warning')
        expect(rendered).to have_content(
          strip_tags(t('account.index.verification.finish_verifying_html', sp_name:)),
        )
        expect(rendered).to have_link(t('account.index.verification.continue_idv'), href: idv_path)
      end
    end

    context 'with non-facial match proofed user' do
      let(:user) { build(:user, :proofed) }

      it 'shows unverified badge' do
        expect(rendered).to have_content(t('account.index.verification.unverified_badge'))
      end

      it 'shows content explaining that the user needs to verify their identity again' do
        expect(rendered).to have_content(
          strip_tags(
            t(
              'account.index.verification.legacy_verified_html',
              app_name: APP_NAME,
              date: @presenter.formatted_legacy_idv_date,
            ),
          ),
        )
        expect(rendered).to have_content(
          strip_tags(t('account.index.verification.verify_with_facial_match_html', sp_name:)),
        )
        expect(rendered).to have_link(
          t('account.index.verification.learn_more_link'),
          href: help_center_redirect_path(
            category: 'verify-your-identity',
            article: 'overview',
            flow: :account_show,
            location: :idv,
          ),
        )
      end

      it 'shows warning alert instructing user to complete identity verification' do
        expect(rendered).to have_css('.usa-alert.usa-alert--warning')
        expect(rendered).to have_content(
          t('account.index.verification.finish_verifying_no_sp', app_name: APP_NAME),
        )
        expect(rendered).to have_link(t('account.index.verification.continue_idv'), href: idv_path)
      end
    end

    context 'with facial match proofed user' do
      let(:user) { build(:user, :proofed_with_selfie) }

      it 'shows verified badge' do
        expect(rendered).to have_content(t('account.index.verification.verified_badge'))
      end

      it 'shows content confirming verified identity' do
        expect(rendered).to have_content(
          t(
            'account.index.verification.you_verified_your_facial_match_identity',
            app_name: APP_NAME,
          ),
        )
        expect(rendered).to have_link(
          t('account.index.verification.learn_more_link'),
          href: help_center_redirect_path(
            category: 'verify-your-identity',
            article: 'overview',
            flow: :account_show,
            location: :idv,
          ),
        )
      end

      it 'renders pii' do
        expect(rendered).to render_template(partial: 'accounts/_pii')
      end
    end
  end

  describe 'connect to SP alert' do
    let(:post_idv_follow_up_url) { 'https://example.com/followup' }
    let(:initiating_service_provider) do
      build(
        :service_provider,
        friendly_name: initiating_sp_name,
        post_idv_follow_up_url:,
        return_to_sp_url: nil,
      )
    end
    let(:initiating_sp_name) { 'Test SP' }
    let(:user) { create(:user, identities: [identity].compact, profiles: [profile].compact) }
    let(:profile) do
      build(:profile, :active, initiating_service_provider:)
    end
    let(:last_ial2_authenticated_at) { nil }
    let(:identity) do
      build(
        :service_provider_identity,
        service_provider: initiating_service_provider.issuer,
        last_ial2_authenticated_at:,
      )
    end

    context 'with a user who has not connected to their initiating service provider' do
      context 'the service provider has a post-idv follow-up url' do
        it 'renders an alert to connect to IdV SP with a link' do
          expect(rendered).to have_content(
            t(
              'account.index.verification.connect_idv_account.intro',
              sp_name: initiating_sp_name,
            ),
          )
          expect(rendered).to have_link(
            t(
              'account.index.verification.connect_idv_account.cta',
              sp_name: initiating_sp_name,
            ),
            href: post_idv_follow_up_url,
          )
        end
      end

      context 'the service provider does not have a post-idv follow-up url' do
        let(:post_idv_follow_up_url) { nil }

        it 'renders an alert to connect to IdV SP without a link' do
          expect(rendered).to have_content(
            t(
              'account.index.verification.connect_idv_account.intro',
              sp_name: initiating_sp_name,
            ),
          )
          expect(rendered).to have_content(
            t(
              'account.index.verification.connect_idv_account.cta',
              sp_name: initiating_sp_name,
            ),
          )
          expect(rendered).to_not have_link(
            t(
              'account.index.verification.connect_idv_account.cta',
              sp_name: initiating_sp_name,
            ),
          )
        end
      end

      context 'the service provider does not have a name' do
        let(:initiating_sp_name) { nil }

        context 'the service provider has a post-idv follow-up url' do
          it 'does not render the alert' do
            expect(rendered).not_to have_content(
              t(
                'account.index.verification.connect_idv_account.intro',
                sp_name: initiating_sp_name,
              ),
            )
            expect(rendered).not_to have_link(
              t(
                'account.index.verification.connect_idv_account.cta',
                sp_name: initiating_sp_name,
              ),
              href: post_idv_follow_up_url,
            )
          end
        end
      end
    end

    context 'with a user who has connected to their initiating service provider' do
      let(:last_ial2_authenticated_at) { 2.days.ago }

      it 'does not render alert to connect to IdV SP' do
        expect(rendered).to_not have_content(
          strip_tags(
            t('account.index.verification.connect_idv_account.intro'),
          ),
        )
      end
    end
  end

  it 'does not render the NDS identity verification section in the default layout' do
    expect(rendered).to_not have_css('.account__section')
  end

  context 'in the NDS layout' do
    let(:decrypted_pii) { nil }
    let(:locked_for_session) { false }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      @presenter = AccountShowPresenter.new(
        decrypted_pii:,
        sp_session_request_url: nil,
        authn_context:,
        sp_name:,
        user:,
        locked_for_session:,
      )
    end

    def expect_row(text, link_text:, href:)
      expect(rendered).to have_css('.account__panel .account__row-text', text:)
      expect(rendered).to have_link(
        link_text,
        href:,
        class: %w[usa-button--tertiary usa-button--md],
      )
      expect(rendered).to_not have_css('.usa-accordion')
    end

    context 'with an unproofed user and a partner requesting identity verification' do
      let(:sp_name) { 'Example SP' }
      let(:acr_values) do
        [
          Saml::Idp::Constants::IAL_VERIFIED_ACR,
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
        ].join(' ')
      end

      it 'renders the section heading and the not verified row with a Verify link' do
        expect(rendered).to have_css(
          'section.account__section h2.account__heading',
          text: t('account.index.verification.identity_verification'),
        )
        expect_row(
          t('nds.dashboard_account.identity_not_verified'),
          link_text: t('nds.dashboard_account.verify'),
          href: idv_path,
        )
      end
    end

    context 'with user pending gpo verification' do
      let(:user) { create(:user, :with_pending_gpo_profile) }

      it 'links to enter the code from the letter' do
        expect_row(
          t('account.index.verification.instructions'),
          link_text: t('nds.dashboard_account.verify'),
          href: idv_verify_by_mail_enter_code_path,
        )
      end
    end

    context 'with user pending ipp verification' do
      let(:user) { build(:user, :with_pending_in_person_enrollment) }

      it 'shows the Post Office deadline and links to the barcode' do
        expect_row(
          strip_tags(
            t(
              'account.index.verification.in_person_instructions_html',
              deadline: @presenter.formatted_ipp_due_date,
            ),
          ),
          link_text: t('account.index.verification.show_bar_code', app_name: APP_NAME),
          href: idv_in_person_ready_to_verify_url,
        )
      end
    end

    context 'with a profile deactivated for a password reset' do
      before { allow(user).to receive(:password_reset_profile).and_return(true) }

      it 'links to reactivate the profile' do
        expect_row(
          t('account.index.reactivation.instructions'),
          link_text: t('account.index.reactivation.link'),
          href: reactivate_account_path,
        )
      end
    end

    context 'with a non-facial match proofed user and a partner requesting facial match' do
      let(:user) { build(:user, :proofed) }
      let(:sp_name) { 'Example SP' }
      let(:acr_values) do
        [
          Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR,
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
        ].join(' ')
      end

      it 'asks the user to verify again with a photo' do
        expect_row(
          strip_tags(t('account.index.verification.verify_with_facial_match_html', sp_name:)),
          link_text: t('nds.dashboard_account.verify'),
          href: idv_path,
        )
      end
    end

    context 'with a proofed user' do
      let(:user) { build(:user, :proofed) }
      let(:decrypted_pii) do
        Pii::Attributes.new_from_hash(Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE)
      end

      it 'renders the account verified accordion with the verified information' do
        expect(rendered).to have_css(
          '.usa-accordion--bordered button.usa-accordion__button[aria-expanded=false]',
          text: t('nds.dashboard_account.identity_verified'),
        )
        expect(rendered).to have_content(
          strip_tags(
            t(
              'account.index.verification.you_verified_your_identity_html',
              sp_name: APP_NAME,
            ),
          ),
        )
        expect(rendered).to have_css(
          '.usa-accordion__content .card dl.nds-summary .nds-summary__label',
          count: 5,
        )
        expect(rendered).to have_css('.nds-summary__value', text: decrypted_pii.first_name)
        expect(rendered).to have_css('.nds-summary__value', text: '***-**-****')
        expect(rendered).to_not have_content(decrypted_pii.ssn)
        expect(rendered).to have_content(t('account.security.text'))
        expect(rendered).to have_link(
          t('nds.dashboard_account.learn_more'),
          href: help_center_redirect_url,
        )
        expect(rendered).to_not have_css('.usa-tooltip')
      end

      context 'when the information is locked for the session' do
        let(:locked_for_session) { true }

        it 'hides the information and offers to authenticate again' do
          expect(rendered).to_not have_content(decrypted_pii.first_name)
          expect(rendered).to have_content(t('account.re_verify.banner'))
          expect(rendered).to have_css(
            "form[action='#{account_reauthentication_path}'][method=post] " \
              "button.usa-button--tertiary",
            text: t('account.re_verify.footer'),
          )
          expect(rendered).to_not have_link(t('nds.dashboard_account.learn_more'))
        end
      end
    end

    context 'with a facial match proofed user' do
      let(:user) { build(:user, :proofed_with_selfie) }

      it 'confirms the facial match verification' do
        expect(rendered).to have_content(
          t(
            'account.index.verification.you_verified_your_facial_match_identity',
            app_name: APP_NAME,
          ),
        )
      end
    end
    context 'with a verified user who has not connected to their initiating service provider' do
      let(:initiating_sp_name) { 'Test SP' }
      let(:post_idv_follow_up_url) { 'https://example.com/followup' }
      let(:initiating_service_provider) do
        build(
          :service_provider,
          friendly_name: initiating_sp_name,
          post_idv_follow_up_url:,
          return_to_sp_url: nil,
        )
      end
      let(:user) do
        create(:user, profiles: [build(:profile, :active, initiating_service_provider:)])
      end

      it 'renders the warning alert to connect, linking to the follow-up url' do
        expect(rendered).to have_css(
          '.account__section .usa-alert--warning',
          text: t(
            'account.index.verification.connect_idv_account.intro',
            sp_name: initiating_sp_name,
          ),
        )
        expect(rendered).to have_link(
          t('account.index.verification.connect_idv_account.cta', sp_name: initiating_sp_name),
          href: post_idv_follow_up_url,
        )
      end

      context 'when the user has connected to the initiating service provider' do
        let(:user) do
          create(
            :user,
            profiles: [build(:profile, :active, initiating_service_provider:)],
            identities: [
              build(
                :service_provider_identity,
                service_provider: initiating_service_provider.issuer,
                last_ial2_authenticated_at: 2.days.ago,
              ),
            ],
          )
        end

        it 'does not render the connect alert' do
          expect(rendered).to_not have_css('.usa-alert--warning')
        end
      end
    end
  end
end
