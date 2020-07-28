require 'rails_helper'

describe 'idv/doc_auth/welcome.html.erb' do
  let(:flow_session) { {} }
  let(:user_fully_authenticated) { true }

  before do
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:user_fully_authenticated?).and_return(user_fully_authenticated)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  context 'in doc auth with an authenticated user' do
    it 'renders a link to return to the SP' do
      render template: 'idv/doc_auth/welcome.html.erb'

      expect(rendered).to have_link(t('links.cancel'))
    end
  end

  context 'in recovery without an authenticated user' do
    let(:user_fully_authenticated) { false }

    it 'renders a link to return to the MFA step' do
      render template: 'idv/doc_auth/welcome.html.erb'

      expect(rendered).to have_link(t('two_factor_authentication.choose_another_option'))
    end
  end
end
