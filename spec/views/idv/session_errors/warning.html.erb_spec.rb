require 'rails_helper'

RSpec.describe 'idv/session_errors/warning.html.erb' do
  let(:sp_name) { nil }
  let(:try_again_path) { '/example/path' }
  let(:remaining_attempts) { 5 }
  let(:user_session) { {} }

  before do
    decorated_session = instance_double(ServiceProviderSession, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    allow(view).to receive(:user_session).and_return(user_session)

    assign(:remaining_attempts, remaining_attempts)
    assign(:try_again_path, try_again_path)

    render
  end

  it 'shows a primary action' do
    expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
  end

  it 'shows remaining attempts' do
    expect(rendered).to have_text(
      strip_tags(
        t('idv.warning.attempts_html', count: remaining_attempts),
      ),
    )
  end

  it 'shows a cancel link' do
    expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path)
  end

  context 'with a nil user_session' do
    let(:user_session) { nil }

    it 'does not render troubleshooting option to retake photos' do
      expect(rendered).to have_link(t('idv.failure.button.warning'), href: try_again_path)
      expect(rendered).to have_text(
        strip_tags(
          t('idv.warning.attempts_html', count: remaining_attempts),
        ),
      )
      expect(rendered).to have_link(t('links.cancel'), href: idv_cancel_path)
    end
  end
end
