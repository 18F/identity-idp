require 'rails_helper'

RSpec.describe 'idv/not_verified/show.html.erb' do
  let(:sp_name) { nil }

  before do
    allow(view).to receive(:decorated_sp_session).and_return(
      instance_double(ServiceProviderSession, sp_name: sp_name),
    )

    render
  end

  context 'without an sp' do
    it 'renders the fail link text with application name' do
      expect(rendered).to have_text(
        strip_tags(
          t(
            'idv.failure.verify.fail_link_html',
            sp_name: APP_NAME,
          ),
        ),
      )
    end
  end

  context 'with an sp' do
    let(:sp_name) { 'Department of Departments' }
    it 'renders the fail link text with the SP name' do
      expect(rendered).to have_text(
        strip_tags(
          t('idv.failure.verify.fail_link_html', sp_name: sp_name),
        ),
      )
    end
  end

  describe('exit button') do
    it 'is rendered' do
      expect(rendered).to have_selector(
        'a',
        text: t('idv.failure.verify.exit', app_name: APP_NAME),
      )
    end
    it 'links to the right place' do
      expect(rendered).to have_link(
        t('idv.failure.verify.exit', app_name: APP_NAME),
        href: return_to_sp_failure_to_proof_path,
      )
    end
  end
end
