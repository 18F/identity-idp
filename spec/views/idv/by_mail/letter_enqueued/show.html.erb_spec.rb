require 'rails_helper'

RSpec.describe 'idv/by_mail/letter_enqueued/show.html.erb' do
  let(:service_provider) { '🔒🌐💻' }
  let(:step_indicator_steps) { Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO }

  let(:pii_from_doc) do
    {}
  end

  let(:idv_session) do
    idv_session = Idv::Session.new(
      user_session: {},
      current_user: nil,
      service_provider: service_provider,
    )
    idv_session.pii_from_doc = pii_from_doc
    idv_session
  end

  before do
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
    render
  end

  it 'renders the come back later message' do
    expect(rendered).to have_content(
      strip_tags(
        t('idv.messages.come_back_later_html'),
      ),
    )
  end

  context 'with an SP' do
    it 'renders a return to SP button' do
      expect(rendered).to have_link(
        t('idv.cancel.actions.exit', app_name: APP_NAME),
        href: return_to_sp_cancel_path(step: :get_a_letter, location: :come_back_later),
      )
    end
  end

  context 'without an SP' do
    let(:service_provider) { nil }

    it 'renders a return to account button' do
      expect(rendered).to have_link(
        t('idv.buttons.continue_plain'),
        href: account_path,
      )
    end
  end

  it 'shows step indicator with current step' do
    expect(view.content_for(:pre_flash_content)).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.get_a_letter'),
    )
  end

  context 'when address line 2 is not present' do
    let(:pii_from_doc) do
      {
        address1: '123 Identical Ct.',
        city: 'Suburbia',
        state: 'US',
        zipcode: '99999',
      }
    end

    it 'renders the correct two-line address' do
      expect(rendered).to have_selector('div>p', text: '123 Identical Ct')
      expect(rendered).to have_selector('div>p', text: 'Suburbia, US 99999')
    end
  end

  context 'when address line 2 is present' do
    let(:pii_from_doc) do
      {
        address1: '456 Big Building Blvd',
        address2: 'Unit 42',
        city: 'Downtown',
        state: 'US',
        zipcode: '99999',
      }
    end

    it 'renders the correct three-line address' do
      expect(rendered).to have_selector('div>p', text: '456 Big Building Blvd')
      expect(rendered).to have_selector('div>p', text: 'Unit 42')
      expect(rendered).to have_selector('div>p', text: 'Downtown, US 99999')
    end
  end
end
