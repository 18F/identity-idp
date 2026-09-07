require 'rails_helper'

RSpec.describe 'idv/session_errors/warning.html.erb' do
  let(:sp_name) { nil }
  let(:try_again_path) { '/example/path' }
  let(:remaining_submit_attempts) { 5 }
  let(:user_session) { {} }
  let(:nds_layout) { false }

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    allow(view).to receive(:user_session).and_return(user_session)
    allow(view).to receive(:nds_layout?).and_return(nds_layout)

    assign(:remaining_submit_attempts, remaining_submit_attempts)
    assign(:try_again_path, try_again_path)

    @step_indicator_steps = Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
  end

  it 'shows remaining attempts' do
    expect(rendered).to have_text(
      strip_tags(
        t('idv.failure.attempts_html', count: remaining_submit_attempts),
      ),
    )
  end

  it 'shows a cancel link' do
    expect(rendered).to have_link(
      t('links.cancel'),
      href: idv_cancel_path(step: :invalid_session),
    )
  end

  context 'with a nil user_session' do
    let(:user_session) { nil }

    it 'does not render troubleshooting option to retake photos' do
      expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
      expect(rendered).to have_text(
        strip_tags(
          t('idv.failure.attempts_html', count: remaining_submit_attempts),
        ),
      )
      expect(rendered).to have_link(
        t('links.cancel'),
        href: idv_cancel_path(step: :invalid_session),
      )
    end
  end

  it 'does not render the NDS form-page card in the default layout' do
    expect(rendered).to_not have_selector('.auth--form-page')
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the form-page card with the warning heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector(
        '.auth--form-page h1',
        text: t('idv.warning.sessions.heading'),
      )
    end

    it 'sets the verification header progress' do
      progress = view.content_for(:nds_header_progress)
      expect(progress).to have_css('nds-progress .progress__step[aria-current="step"]')
    end

    it 'renders the warning status-icon badge and divider' do
      expect(rendered).to have_selector('.auth__header--with-media .nds-status-icon--warning')
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'shows remaining attempts in the body' do
      expect(rendered).to have_selector(
        '.auth__form-page-body',
        text: strip_tags(t('idv.failure.attempts_html', count: remaining_submit_attempts)),
      )
    end

    it 'shows the try-again and cancel actions' do
      expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
      expect(rendered).to have_link(
        t('links.cancel'),
        href: idv_cancel_path(step: :invalid_session),
      )
    end

    it 'does not render any l13n markers' do
      expect(rendered).not_to include('%{')
    end
  end
end
