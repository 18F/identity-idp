require 'rails_helper'

describe 'idv/come_back_later/show.html.erb' do
  let(:sp_name) { '🔒🌐💻' }
  let(:step_indicator_steps) { Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS_GPO }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:step_indicator_steps).and_return(step_indicator_steps)
  end

  context 'with an SP' do
    it 'renders a return to SP button' do
      render
      expect(rendered).to have_link(
        t('idv.buttons.continue_plain'),
        href: return_to_sp_cancel_path(location: :come_back_later),
      )
    end

    it 'renders return to SP message' do
      render
      expect(rendered).to have_content(
        strip_tags(
          t(
            'idv.messages.come_back_later_sp_html',
            sp: @decorated_session.sp_name,
          ),
        ),
      )
    end
  end

  context 'without an SP' do
    let(:sp_name) { nil }

    it 'renders a return to account button' do
      render
      expect(rendered).to have_link(
        t('idv.buttons.continue_plain', sp: sp_name),
        href: account_path,
      )
    end

    it 'renders return to account message' do
      render
      expect(rendered).to have_content(
        strip_tags(
          t(
            'idv.messages.come_back_later_no_sp_html',
            app_name: APP_NAME,
          ),
        ),
      )
    end
  end

  it 'shows step indicator with current step' do
    render

    expect(view.content_for(:pre_flash_content)).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.get_a_letter'),
    )
  end
end
