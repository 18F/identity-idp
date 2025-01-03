require 'rails_helper'

RSpec.describe 'accounts/show.html.erb' do
  let(:authn_context) { Vot::Parser::Result.no_sp_result }
  let(:user) { create(:user, :fully_registered, :with_personal_key) }
  let(:vtr) { ['C2'] }
  let(:authn_context) do
    AuthnContextResolver.new(
      user:,
      service_provider: nil,
      vtr: vtr,
      acr_values: nil,
    ).result
  end
  before do
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
        all_emails_requested: false,
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

  context 'when current user has an in_person_enrollment that was failed' do
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

  context 'when current user has an in_person_enrollment that was cancelled' do
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

  context 'when current user has an in_person_enrollment that expired' do
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
          all_emails_requested: false,
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
end
