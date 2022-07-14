require 'rails_helper'

describe 'idv/cancellations/destroy.html.erb' do
  let(:hybrid_session) { false }
  let(:sp_name) { nil }
  let(:return_to_sp_path) { root_url }

  before do
    decorated_session = instance_double(ServiceProviderSessionDecorator, sp_name: sp_name)
    allow(view).to receive(:decorated_session).and_return(decorated_session)
    assign(:hybrid_session, hybrid_session)
    assign(:return_to_sp_path, return_to_sp_path)

    render
  end

  context 'with hybrid flow' do
    let(:hybrid_session) { true }

    it 'renders heading' do
      expect(rendered).to have_text(t('idv.cancel.headings.confirmation.hybrid'))
    end

    it 'renders content' do
      expect(rendered).to have_text(t('doc_auth.instructions.switch_back'))
    end
  end

  context 'with standard flow' do
    let(:hybrid_session) { false }

    it 'renders heading' do
      expect(rendered).to have_text(t('headings.cancellations.confirmation', app_name: APP_NAME))
    end

    it 'renders content' do
      expect(rendered).to have_text(t('idv.cancel.warnings.warning_2'))
    end

    context 'without associated service provider' do
      let(:sp_name) { nil }

      it 'renders link to account page' do
        expect(rendered).to have_link(
          "‹ #{t('links.back_to_sp', sp: t('links.my_account'))}",
          href: account_url,
        )
      end
    end

    context 'with associated service provider' do
      let(:sp_name) { 'Example Service Provider' }

      it 'renders link to return to sp' do
        expect(rendered).to have_link(
          "‹ #{t('links.back_to_sp', sp: sp_name)}",
          href: return_to_sp_path,
        )
      end
    end
  end
end
