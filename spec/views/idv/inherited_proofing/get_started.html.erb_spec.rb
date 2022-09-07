require 'rails_helper'

describe 'idv/inherited_proofing/get_started.html.erb' do
  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:locale) { nil }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
  end

  it 'renders the Continue button' do
    render template: 'idv/inherited_proofing/get_started'

    expect(rendered).to have_button(t('inherited_proofing.buttons.continue'))
  end

  describe 'I18n' do
    before do
      view.locale = locale

      render template: 'idv/inherited_proofing/get_started'
    end

    context 'when rendered using the default locale' do
      let(:locale) { nil }

      it 'renders the correct language' do
        expect(rendered).to have_content('Get started verifying your identity')
      end
    end

    context 'when rendered using the French (:fr) locale' do
      let(:locale) { :fr }

      it 'renders the correct language' do
        expect(rendered).to have_content('Commencez à vérifier votre identité')
      end
    end

    context 'when rendered using the Spanish (:es) locale' do
      let(:locale) { :es }

      it 'renders using the correct locale' do
        expect(rendered).to have_content('Empiece con la verificación de su identidad')
      end
    end
  end
end
