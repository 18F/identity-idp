require 'rails_helper'

RSpec.describe 'idv/by_mail/letter_enqueued/show.html.erb' do
  let(:service_provider) { create(:service_provider) }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO }
  let(:nds_layout) { false }
  let(:flash_success) { nil }

  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT }

  let(:idv_session) do
    idv_session = Idv::Session.new(
      user_session: {},
      current_user: nil,
      service_provider: service_provider,
    )
    idv_session.applicant = applicant_pii
    idv_session
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    assign(
      :presenter,
      Idv::ByMail::LetterEnqueuedPresenter.new(
        idv_session: idv_session,
        user_session: {},
        url_options: {},
        current_user: nil,
      ),
    )

    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
    flash[:success] = flash_success if flash_success
    render
  end

  it 'has the legacy localized title in the default layout' do
    expect(view.content_for(:title)).to eq(t('titles.idv.come_back_soon'))
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    it 'renders the come back later message' do
      expect(rendered).to have_content(
        strip_tags(
          t('idv.messages.come_back_later'),
        ),
      )
    end

    context 'with an SP' do
      it 'renders a return to SP button' do
        expect(rendered).to have_link(
          t('idv.cancel.actions.exit', app_name: APP_NAME),
          href: return_to_sp_cancel_path(step: :verify_address, location: :come_back_later),
        )
      end
    end

    context 'without an SP' do
      let(:service_provider) { nil }

      it 'renders a return to Login.gov button' do
        expect(rendered).to have_link(
          t('idv.cancel.actions.exit', app_name: APP_NAME),
          href: marketing_site_redirect_path,
        )
      end
    end

    it 'shows step indicator with current step' do
      expect(view.content_for(:pre_flash_content)).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_address'),
      )
    end

    context 'when address line 2 is not present' do
      let(:applicant_pii) do
        super().merge(
          {
            address1: '123 Identical Ct.',
            city: 'Suburbia',
            state: 'US',
            zipcode: '99999',
          },
        )
      end

      it 'renders the correct two-line address' do
        expect(rendered).to have_selector('div>p', text: '123 Identical Ct')
        expect(rendered).to have_selector('div>p', text: 'Suburbia, US 99999')
      end
    end

    context 'when address line 2 is present' do
      let(:applicant_pii) do
        super().merge(
          {
            address1: '456 Big Building Blvd',
            address2: 'Unit 42',
            city: 'Downtown',
            state: 'US',
            zipcode: '99999',
          },
        )
      end

      it 'renders the correct three-line address' do
        expect(rendered).to have_selector('div>p', text: '456 Big Building Blvd')
        expect(rendered).to have_selector('div>p', text: 'Unit 42')
        expect(rendered).to have_selector('div>p', text: 'Downtown, US 99999')
      end
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'has a title matching the letter on the way heading' do
      expect(view.content_for(:title)).to eq(t('idv.titles.come_back_later'))
    end

    it 'renders the form-page card with the heading and intro' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css('.auth--form-page h1', text: t('idv.titles.come_back_later'))
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: t('idv.gpo.will_send_to', app_name: APP_NAME),
      )
      expect(rendered).to have_css('.auth__header .nds-status-icon.nds-status-icon--info svg')
    end

    it 'pins the progress to the enter password substep and drops the legacy step indicator' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"] .progress__step-counter',
        text: '10 / 12',
      )
      expect(view.content_for(:pre_flash_content)).to be_nil
    end

    it 'renders the address summary and the come back later message' do
      expect(rendered).to have_css(
        '.card--elevated .nds-summary__label',
        text: t('nds.verify_info.address'),
      )
      expect(rendered).to have_css('.nds-summary__value', text: '1 FAKE RD')
      expect(rendered).to have_css('.nds-summary__value', text: 'GREAT FALLS, MT 59010')
      expect(rendered).to have_content(t('idv.messages.come_back_later'))
    end

    context 'with an SP' do
      it 'tells the user to contact the SP and exits back to it' do
        exit_path = return_to_sp_cancel_path(step: :verify_address, location: :come_back_later)
        expect(rendered).to have_link(service_provider.friendly_name, href: exit_path)
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{exit_path}']",
          text: t('idv.cancel.actions.exit', app_name: APP_NAME),
        )
      end
    end

    context 'without an SP' do
      let(:service_provider) { nil }

      it 'exits to Login.gov without the SP contact message' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{marketing_site_redirect_path}']",
          text: t('idv.cancel.actions.exit', app_name: APP_NAME),
        )
        expect(rendered).to have_css('.auth__form-page-body .copy--muted p', count: 1)
      end
    end

    context 'when address line 2 is present' do
      let(:applicant_pii) { super().merge(address2: 'Unit 42') }

      it 'renders the address line' do
        expect(rendered).to have_css('.nds-summary__value', text: 'Unit 42')
      end
    end

    context 'after requesting another letter' do
      let(:flash_success) { t('idv.messages.gpo.another_letter_on_the_way') }

      it 'renders the success flash in the card' do
        expect(rendered).to have_css(
          'section.auth--form-page .usa-alert--success',
          text: t('idv.messages.gpo.another_letter_on_the_way'),
        )
      end
    end
  end
end
