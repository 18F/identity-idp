require 'rails_helper'

RSpec.describe 'accounts/show.html.erb' do
  let(:authn_context) { Component::Parser::Result.no_sp_result }
  let(:user) { create(:user, :fully_registered, :with_personal_key) }
  let(:authn_context) do
    AuthnContextResolver.new(
      user:,
      service_provider: nil,
      acr_values: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
    ).result
  end
  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return({})
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        user: user,
        sp_session_request_url: nil,
        authn_context:,
        sp_name: nil,
        locked_for_session: false,
      ),
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('titles.account'))

    render
  end

  context 'when current user has a verified account' do
    let(:user) { build(:user, :proofed) }

    it 'renders idv partial' do
      expect(render).to render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'when current user has password_reset_profile' do
    before do
      allow(user).to receive(:password_reset_profile).and_return(true)
    end

    it 'displays an alert with instructions to reactivate their profile' do
      render

      expect(rendered).to have_content(t('account.index.reactivation.instructions'))
    end

    it 'contains link to reactivate profile via personal key or reverification' do
      render

      expect(rendered).to have_link(
        t('account.index.reactivation.link'),
        href: reactivate_account_path,
      )
    end
  end

  context 'when the user does not have pending_profile' do
    before do
      allow(user).to receive(:pending_profile).and_return(nil)
    end

    it 'lacks a pending profile section' do
      render

      expect(rendered).to_not have_link(
        t('account.index.verification.reactivate_button'), href: idv_verify_by_mail_enter_code_path
      )
    end
  end

  context 'when current user has gpo pending profile' do
    let(:user) { create(:user, :with_pending_gpo_profile) }

    it 'renders idv partial' do
      expect(render).to render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'when current user has gpo pending profile deactivated for password reset' do
    let(:user) { create(:user, :with_pending_gpo_profile) }

    it 'does not render idv partial' do
      user.profiles.first.update!(deactivation_reason: :password_reset)
      expect(render).to_not render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'when current user has ipp pending profile' do
    let(:user) { create(:user, :with_pending_in_person_enrollment) }

    it 'renders idv partial' do
      expect(render).to render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'when current user has ipp pending profile deactivated for password reset' do
    let(:user) { create(:user, :with_pending_in_person_enrollment) }

    it 'does not render idv partial' do
      user.profiles.first.update!(deactivation_reason: :password_reset)
      expect(render).to_not render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'when current user has an in_person_enrollment that was failed',
          skip: 'VoT has been deprecated. EIPP should not be determined via acr_values' do
    let(:vtr) { ['Pe'] }
    let(:sp_name) { 'sinatra-test-app' }
    let(:user) { create(:user, :with_pending_in_person_enrollment) }

    before do
      # Make the in_person_enrollment and associated profile failed
      in_person_enrollment = user.in_person_enrollments.first
      in_person_enrollment.update!(status: :failed, status_check_completed_at: Time.zone.now)
      profile = user.profiles.first
      profile.deactivate_due_to_in_person_verification_cancelled
    end

    it 'renders the idv partial' do
      expect(render).to render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'when current user has an in_person_enrollment that was cancelled',
          skip: 'VoT has been deprecated. EIPP should not be determined via acr_values' do
    let(:vtr) { ['Pe'] }
    let(:sp_name) { 'sinatra-test-app' }
    let(:user) { create(:user, :with_pending_in_person_enrollment) }

    before do
      # Make the in_person_enrollment and associated profile cancelled
      in_person_enrollment = user.in_person_enrollments.first
      in_person_enrollment.update!(status: :cancelled, status_check_completed_at: Time.zone.now)
      profile = user.profiles.first
      profile.deactivate_due_to_in_person_verification_cancelled
    end

    it 'renders the idv partial' do
      expect(render).to render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'when current user has an in_person_enrollment that expired',
          skip: 'VoT has been deprecated. EIPP should not be determined via acr_values' do
    let(:vtr) { ['Pe'] }
    let(:sp_name) { 'sinatra-test-app' }
    let(:user) { create(:user, :with_pending_in_person_enrollment) }

    before do
      # Expire the in_person_enrollment and associated profile
      in_person_enrollment = user.in_person_enrollments.first
      in_person_enrollment.update!(status: :expired, status_check_completed_at: Time.zone.now)
      profile = user.profiles.first
      profile.deactivate_due_to_in_person_verification_cancelled
    end

    it 'renders the idv partial' do
      expect(render).to render_template(partial: 'accounts/_identity_verification')
    end
  end

  context 'phone listing and adding' do
    context 'user has no phone' do
      let(:user) do
        record = create(:user, :fully_registered, :with_piv_or_cac)
        record.phone_configurations = []
        record
      end

      it 'does not render phone' do
        render

        expect(view).to_not render_template(partial: '_phone')
      end
    end

    context 'user has a phone' do
      it 'renders the phone section' do
        render

        expect(view).to render_template(partial: '_phone')
      end

      it 'formats phone numbers' do
        user.phone_configurations.first.tap do |phone_configuration|
          phone_configuration.phone = '+18888675309'
          phone_configuration.save
        end
        render
        expect(rendered).to have_selector('.grid-col-fill', text: '+1 888-867-5309')
      end
    end
  end

  context 'PIV/CAC listing and adding' do
    context 'user has no piv/cac' do
      let(:user) { create(:user, :fully_registered, :with_authentication_app) }

      it 'does not render piv/cac' do
        render

        expect(view).to_not render_template(partial: '_piv_cac')
      end
    end

    context 'user has a piv/cac' do
      let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

      it 'renders the piv/cac section' do
        render

        expect(view).to render_template(partial: '_piv_cac')
      end
    end
  end

  context 'email listing and adding' do
    let(:user) do
      record = create(:user)
      record
    end

    it 'renders the email section' do
      render

      expect(view).to render_template(partial: '_emails')
    end

    it 'shows one email if the user has only one email' do
      expect(user.email_addresses.size).to eq(1)
    end

    it 'shows one email if the user has only one email' do
      create_list(:email_address, 4, user: user)
      user.reload
      expect(user.email_addresses.size).to eq(5)
    end
  end

  context 'when a profile has just been re-activated with personal key during SP auth' do
    let(:sp) { build(:service_provider, return_to_sp_url: 'https://www.example.com/auth') }
    before do
      assign(
        :presenter,
        AccountShowPresenter.new(
          decrypted_pii: nil,
          user: user,
          sp_session_request_url: sp.return_to_sp_url,
          authn_context:,
          sp_name: sp.friendly_name,
          locked_for_session: false,
        ),
      )
    end

    it 'renders the link to continue to the SP' do
      render

      expect(rendered).to have_link(
        t('account.index.continue_to_service_provider', service_provider: sp.friendly_name),
        href: sp.return_to_sp_url,
      )
    end
  end

  describe 'email language' do
    context 'without explicit user language preference' do
      let(:user) { create(:user, :fully_registered, email_language: nil) }

      before do
        I18n.locale = :es
      end

      it 'renders email language with language of parts as English' do
        # Ensure that non-English content in English page is annotated with language.
        # See: https://www.w3.org/WAI/WCAG21/Understanding/language-of-parts
        render

        expect(rendered).to have_css('[lang=en]', text: t('account.email_language.name.en'))
      end
    end

    context 'with user language preference' do
      let(:user) { create(:user, :fully_registered, email_language: :es) }

      it 'renders email language with language of parts as that language' do
        # Ensure that non-English content in English page is annotated with language.
        # See: https://www.w3.org/WAI/WCAG21/Understanding/language-of-parts
        render

        expect(rendered).to have_css('[lang=es]', text: t('account.email_language.name.es'))
      end
    end
  end

  it 'does not render the NDS account sections in the default layout' do
    render

    expect(rendered).to_not have_css('.account')
    expect(rendered).to_not have_css('.account__section')
  end

  context 'in the NDS layout' do
    let(:user) { create(:user, :fully_registered, :with_personal_key, :with_multiple_emails) }

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders one visually hidden page heading and the Figma sections in order' do
      render

      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.account > h1.usa-sr-only',
        text: t('headings.account.login_info'),
      )
      headings = rendered.scan(%r{<h2 class="account__heading">([^<]+)</h2>}).flatten.map(&:strip)
      expect(headings).to eq(
        [
          t('account.index.email_preferences'),
          t('account.index.password'),
          t('account.verified_information.phone_number'),
          t('account.items.personal_key'),
          t('account.navigation.delete_account'),
        ],
      )
    end

    it 'leaves the authentication methods to the Security tab' do
      user.auth_app_configurations.create!(name: 'App', otp_secret_key: ROTP::Base32.random_base32)
      render

      expect(view).to_not render_template(partial: 'accounts/_auth_apps')
      expect(view).to_not render_template(partial: 'accounts/_backup_codes')
      expect(view).to_not render_template(partial: 'accounts/_phone')
      expect(view).to_not render_template(partial: 'accounts/_manage_personal_key')
    end

    it 'lists each email with a delete link and links to add an email' do
      render

      user.email_addresses.each do |email|
        expect(rendered).to have_css('.account__row', text: email.email)
        expect(rendered).to have_link(
          "#{t('forms.buttons.delete')} #{email.email}",
          href: manage_email_confirm_delete_url(id: email.id),
          class: %w[usa-button--tertiary usa-button--md],
        )
      end
      expect(rendered).to have_link(
        t('account.navigation.add_email'),
        href: add_email_path,
        class: %w[usa-button--secondary usa-button--md],
      )
    end

    it 'marks unconfirmed emails with a warning badge' do
      create(:email_address, user:, email: 'new@example.com', confirmed_at: nil)
      user.reload
      render

      expect(rendered).to have_css(
        '.account__row',
        text: /new@example\.com\s+#{t('nds.dashboard_account.unconfirmed')}/,
      )
      expect(rendered).to have_css('.badge.badge--warning', count: 1)
    end

    it 'shows the email limit error from the flash' do
      flash[:email_error] = t('email_addresses.add.limit')
      render

      expect(rendered).to have_css('.usa-alert--error#emails', text: t('email_addresses.add.limit'))
    end

    it 'links the email language, password, personal key and delete account rows' do
      render

      expect(rendered).to have_link(
        "#{t('nds.dashboard_account.change')} #{t('i18n.language')}",
        href: account_email_language_path,
      )
      expect(rendered).to have_css(
        '.account__row [lang=en]',
        text: t('account.email_language.name.en'),
      )
      expect(rendered).to have_link(
        "#{t('nds.dashboard_account.change')} #{t('account.index.password')}",
        href: manage_password_path,
      )
      expect(rendered).to have_content(t('account.personal_key.reset_instructions'))
      expect(rendered).to have_link(
        "#{t('account.links.regenerate_personal_key')} #{t('account.items.personal_key')}",
        href: create_new_personal_key_url,
      )
      expect(rendered).to have_content(t('nds.dashboard_account.delete_account_info'))
      expect(rendered).to have_css(
        "a.account__danger-action[href='#{account_delete_path}']" \
          "[aria-label='#{t('account.items.delete_your_account')}']",
        text: t('account.links.delete_account'),
      )
    end

    it 'lists each phone with a manage link, marks the default one and links to add a phone' do
      create(:phone_configuration, user:, phone: '+1 202-555-1213')
      user.reload
      render

      user.phone_configurations.each do |phone_configuration|
        formatted_phone = PhoneFormatter.format(phone_configuration.phone)
        expect(rendered).to have_link(
          "#{t('forms.buttons.manage')} #{formatted_phone}",
          href: manage_phone_path(id: phone_configuration.id),
        )
      end
      expect(rendered).to have_css(
        '.account__row',
        text: /#{Regexp.escape(PhoneFormatter.format(user.default_phone_configuration.phone))}\s+
               #{t('nds.dashboard_account.primary')}/x,
      )
      expect(rendered).to have_css('.badge.badge--primary', count: 1)
      expect(rendered).to have_link(
        t('account.navigation.add_phone_number'),
        href: phone_setup_path,
      )
    end

    it 'does not mark a single phone as primary' do
      render

      expect(rendered).to_not have_content(t('nds.dashboard_account.primary'))
    end

    context 'when the user has no phone' do
      let(:user) do
        record = create(:user, :fully_registered, :with_piv_or_cac)
        record.phone_configurations = []
        record
      end

      it 'does not render the phone section' do
        render

        expect(rendered).to_not have_content(t('account.verified_information.phone_number'))
      end
    end

    context 'when the personal key can no longer be regenerated' do
      before do
        allow_any_instance_of(AccountShowPresenter).to receive(
          :show_regenerate_personal_key_action?,
        ).and_return(false)
      end

      it 'keeps the instructions without the reset link' do
        render

        expect(rendered).to have_content(t('account.personal_key.reset_instructions'))
        expect(rendered).to_not have_link(href: create_new_personal_key_url)
      end
    end

    it 'does not render the identity verification section for an unverified user' do
      render

      expect(rendered).to_not have_content(t('account.index.verification.identity_verification'))
    end

    context 'when current user has a verified account' do
      let(:user) { create(:user, :proofed) }

      it 'renders the identity verification section' do
        expect(render).to render_template(partial: 'accounts/_identity_verification')
        expect(rendered).to have_css(
          '.account__section .usa-accordion__button',
          text: t('nds.dashboard_account.identity_verified'),
        )
      end
    end

    context 'when current user has password_reset_profile' do
      before do
        allow(user).to receive(:password_reset_profile).and_return(true)
      end

      it 'shows the reactivation row in the identity verification section' do
        render

        expect(rendered).to have_css(
          '.account__section .account__row',
          text: t('account.index.reactivation.instructions'),
        )
        expect(rendered).to have_link(
          t('account.index.reactivation.link'),
          href: reactivate_account_path,
          class: 'usa-button--tertiary',
        )
      end
    end

    context 'when a profile has just been re-activated with personal key during SP auth' do
      let(:sp) { build(:service_provider, return_to_sp_url: 'https://www.example.com/auth') }
      before do
        assign(
          :presenter,
          AccountShowPresenter.new(
            decrypted_pii: nil,
            user: user,
            sp_session_request_url: sp.return_to_sp_url,
            authn_context:,
            sp_name: sp.friendly_name,
            locked_for_session: false,
          ),
        )
      end

      it 'renders the continue to SP alert above the sections' do
        render

        expect(rendered).to have_css('.account__alerts .usa-alert--info')
        expect(rendered).to have_link(
          t('account.index.continue_to_service_provider', service_provider: sp.friendly_name),
          href: sp.return_to_sp_url,
        )
      end
    end
  end
end
