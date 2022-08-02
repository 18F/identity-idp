require 'rails_helper'

describe 'idv/session_errors/warning.html.erb' do
  let(:sp_name) { nil }
  let(:try_again_path) { '/example/path' }
  let(:remaining_attempts) { 5 }
  let(:user_session) { {} }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
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
    expect(rendered).to have_text(t('idv.failure.attempts', count: remaining_attempts))
  end

  it 'does not display troubleshooting options' do
    expect(rendered).not_to have_content(t('components.troubleshooting_options.default_heading'))
  end

  context 'with an associated service provider' do
    let(:sp_name) { 'Example SP' }

    it 'renders troubleshooting option to get help at service provider' do
      expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        href: return_to_sp_failure_to_proof_path(step: 'verify_info', location: 'warning'),
      )
    end
  end

  context 'with a flow session which had a barcode attention document capture result' do
    let(:user_session) { { 'idv/doc_auth': { had_barcode_read_failure: true } } }

    it 'renders troubleshooting option to retake photos' do
      expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.add_new_photos'),
        href: idv_doc_auth_step_path(step: :redo_document_capture),
      )
    end
  end
end
