require 'rails_helper'

describe 'idv/jurisdiction_errors/no_id.html.erb' do
  let(:decorated_session) { instance_double(ServiceProviderSessionDecorator) }
  let(:sp_name) { 'Test SP' }
  let(:failure_to_proof_url) { 'https://sp.example.com/failed' }

  before do
    allow(decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(decorated_session).to receive(:failure_to_proof_url).and_return(failure_to_proof_url)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
  end

  context 'with an SP' do
    it 'renders a link to return to the SP' do
      render

      expect(rendered).to have_content(
        strip_tags(t('idv.failure.help.get_help_html', sp_name: sp_name)),
      )
      expect(rendered).to have_link(sp_name, href: failure_to_proof_url)
    end
  end

  context 'without an SP' do
    let(:sp_name) { nil }

    it 'does not render a link to return to the SP' do
      render

      expect(rendered).to_not have_link(sp_name, href: failure_to_proof_url)
    end
  end
end
