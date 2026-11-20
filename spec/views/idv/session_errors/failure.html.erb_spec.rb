require 'rails_helper'

RSpec.describe 'idv/session_errors/failure.html.erb' do
  let(:sp_name) { nil }
  let(:timeout_hours) { 6 }
  let(:nds_layout) { false }
  let(:enrollment) { nil }
  let(:user) { build(:user) }
  let(:action_name) { 'failure' }

  around do |ex|
    freeze_time { ex.run }
  end

  before do
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:action_name).and_return(action_name)
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(IdentityConfig.store).to receive(:idv_attempt_window_in_hours).and_return(timeout_hours)

    @expires_at = Time.zone.now + timeout_hours.hours
    @sp_name = sp_name

    render
  end

  it 'renders a list of troubleshooting options' do
    expect(rendered).to have_link(
      t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      href: contact_redirect_url,
    )
  end

  it 'includes a message instructing when they can try again' do
    expect(rendered).to have_text(
      strip_tags(
        t(
          'idv.failure.sessions.fail_html',
          timeout: distance_of_time_in_words(timeout_hours.hours),
        ),
      ),
    )
  end

  it 'links back to the failure_to_proof URL' do
    expect(rendered).to have_link(
      t('idv.failure.exit.without_sp'),
      href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'failure'),
    )
  end

  context 'with an associated service provider' do
    let(:sp_name) { 'Example SP' }

    it 'links back to the SP failure_to_proof URL' do
      expect(rendered).to have_link(
        t(
          'idv.failure.exit.with_sp',
          sp_name: sp_name,
          app_name: 'Login.gov',
        ),
        href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'failure'),
      )
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the exit link as the primary action in the actions stack' do
      expect(rendered).to have_css(
        '.auth__actions a.usa-button:not(.usa-button--tertiary)',
        text: t('nds.errors.return_home'),
      )
      expect(rendered).not_to have_css('.auth__form-page-body strong a')
    end

    it 'keeps the try-again message in the body' do
      expect(rendered).to have_css(
        '.auth__form-page-body',
        text: strip_tags(
          t(
            'idv.failure.sessions.fail_html',
            timeout: distance_of_time_in_words(timeout_hours.hours),
          ),
        ),
      )
    end

    it 'renders the contact-support troubleshooting option as a tertiary new-tab button' do
      expect(rendered).to have_css(
        '.nds-troubleshooting-options a.usa-button--tertiary[target=_blank]',
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      )
    end

    context 'with an associated service provider' do
      let(:sp_name) { 'Example SP' }

      it 'uses the SP exit copy for the primary action' do
        expect(rendered).to have_css(
          '.auth__actions a.usa-button',
          text: t('idv.failure.exit.with_sp', sp_name: sp_name, app_name: 'Login.gov'),
        )
      end
    end

    context 'when the in-person enrollment is for a passport' do
      let(:enrollment) { build(:in_person_enrollment, document_type: :passport_book) }

      it 'renders the passport heading and rate-limit copy' do
        expect(rendered).to have_css('h1', text: t('nds.idv_errors.passport_heading'))
        expect(rendered).to have_css(
          '.auth__form-page-body p',
          text: t('nds.idv_errors.passport_fail'),
        )
        expect(rendered).to have_css(
          '.auth__form-page-body p strong',
          text: strip_tags(
            t(
              'nds.idv_errors.try_again_in_html',
              timeout: distance_of_time_in_words(timeout_hours.hours),
            ),
          ),
        )
        expect(rendered).not_to have_content(t('idv.failure.sessions.heading'))
      end

      it 'renders only the return-home action, without troubleshooting options' do
        expect(rendered).to have_css(
          '.auth__actions a.usa-button',
          text: t('nds.errors.return_home'),
        )
        expect(rendered).to have_link(
          t('nds.errors.return_home'),
          href: return_to_sp_failure_to_proof_path(step: 'verify_id', location: 'failure'),
        )
        expect(rendered).not_to have_css('.nds-troubleshooting-options')
        expect(rendered).not_to have_link(
          t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
        )
      end

      context 'when rendered for the SSN rate limit' do
        let(:action_name) { 'ssn_failure' }

        it 'keeps the personal information copy' do
          expect(rendered).to have_css('h1', text: t('idv.failure.sessions.heading'))
          expect(rendered).not_to have_content(t('nds.idv_errors.passport_fail'))
        end
      end

      context 'with an associated service provider' do
        let(:sp_name) { 'Example SP' }

        it 'returns to the SP' do
          expect(rendered).to have_css(
            '.auth__actions a.usa-button',
            text: t('in_person_proofing.body.barcode.return_to_partner_link', sp_name:),
          )
        end
      end
    end
  end

  context 'with a passport enrollment in the default layout' do
    let(:enrollment) { build(:in_person_enrollment, document_type: :passport_book) }

    it 'keeps the legacy copy' do
      expect(rendered).to have_content(t('idv.failure.sessions.heading'))
      expect(rendered).not_to have_content(t('nds.idv_errors.passport_heading'))
    end
  end
end
