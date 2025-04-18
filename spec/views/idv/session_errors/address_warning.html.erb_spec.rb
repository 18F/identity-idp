require 'rails_helper'

RSpec.describe 'idv/session_errors/address_warning.html.erb' do
  let(:sp_name) { nil }
  let(:address_path) { '/example/path' }
  let(:remaining_submit_attempts) { 5 }
  let(:user_session) { {} }

  before do
    decorated_sp_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_sp_session).and_return(decorated_sp_session)
    allow(view).to receive(:user_session).and_return(user_session)

    assign(:remaining_submit_attempts, remaining_submit_attempts)
    assign(:address_path, address_path)

    @step_indicator_steps = Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: address_path)
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
      expect(rendered).to have_link(t('idv.failure.button.warning'), href: address_path)
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
end
