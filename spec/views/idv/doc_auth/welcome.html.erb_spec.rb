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

  context 'when liveness checking enabled' do
    before do
      allow(view).to receive(:liveness_checking_enabled?).and_return(true)
    end

    it 'renders selfie instructions' do
      render template: 'idv/doc_auth/welcome.html.erb'

      expect(rendered).to have_text(t('doc_auth.instructions.bullet1a'))
    end
  end

  context 'when liveness checking is disabled' do
    before do
      allow(view).to receive(:liveness_checking_enabled?).and_return(false)
    end

    it 'renders selfie instructions' do
      render template: 'idv/doc_auth/welcome.html.erb'

      expect(rendered).to_not have_text(t('doc_auth.instructions.bullet1a'))
    end
  end

  context 'during the acuant maintenance window' do
    let(:start) { Time.zone.parse('2020-01-01T00:00:00Z') }
    let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }
    let(:finish) { Time.zone.parse('2020-01-01T23:59:59Z') }

    before do
      allow(Figaro.env).to receive(:acuant_maintenance_window_start).and_return(start.iso8601)
      allow(Figaro.env).to receive(:acuant_maintenance_window_finish).and_return(finish.iso8601)
    end

    around do |ex|
      Timecop.travel(now) { ex.run }
    end

    it 'renders the warning banner but no other content' do
      render template: 'idv/doc_auth/welcome.html.erb'

      expect(rendered).to have_content('We are currently under maintenance')
      expect(rendered).to_not have_content(t('doc_auth.headings.welcome'))
    end
  end
end
