require 'rails_helper'

describe 'idv/doc_auth/welcome.html.erb' do
  let(:flow_session) { {} }
  let(:user_fully_authenticated) { true }
  let(:sp_name) { nil }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:user_fully_authenticated?).and_return(user_fully_authenticated)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
    allow(view).to receive(:user_signing_up?).and_return(false)
  end

  context 'in doc auth with an authenticated user' do
    let(:need_irs_reproofing) { false }

    before do
      user_decoration = instance_double('user decoration')
      allow(user_decoration).to receive(:reproof_for_irs?).and_return(need_irs_reproofing)
      fake_user = instance_double(User)
      allow(fake_user).to receive(:decorate).and_return(user_decoration)
      assign(:current_user, fake_user)

      render template: 'idv/doc_auth/welcome'
    end

    it 'does not render the IRS reproofing explanation' do
      expect(rendered).not_to have_text(t('doc_auth.info.irs_reproofing_explanation'))
    end

    it 'renders a link to return to the SP' do
      expect(rendered).to have_link(t('links.cancel'))
    end

    context 'when trying to log in to the IRS' do
      let(:need_irs_reproofing) { true }

      it 'renders the IRS reproofing explanation' do
        expect(rendered).to have_text(t('doc_auth.info.irs_reproofing_explanation'))
      end
    end
  end

  context 'in recovery without an authenticated user' do
    let(:user_fully_authenticated) { false }

    it 'renders a link to return to the MFA step' do
      render template: 'idv/doc_auth/welcome'

      expect(rendered).to have_link(t('two_factor_authentication.choose_another_option'))
    end
  end

  it 'renders selfie instructions' do
    render template: 'idv/doc_auth/welcome'

    expect(rendered).to_not have_text(t('doc_auth.instructions.bullet1a'))
  end

  context 'during the acuant maintenance window' do
    let(:start) { Time.zone.parse('2020-01-01T00:00:00Z') }
    let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }
    let(:finish) { Time.zone.parse('2020-01-01T23:59:59Z') }

    before do
      allow(IdentityConfig.store).to receive(:acuant_maintenance_window_start).and_return(start)
      allow(IdentityConfig.store).to receive(:acuant_maintenance_window_finish).and_return(finish)
    end

    around do |ex|
      travel_to(now) { ex.run }
    end

    it 'renders the warning banner but no other content' do
      render template: 'idv/doc_auth/welcome'

      expect(rendered).to have_content('We are currently under maintenance')
      expect(rendered).to_not have_content(t('doc_auth.headings.welcome'))
    end
  end

  context 'without service provider' do
    it 'renders troubleshooting options' do
      render template: 'idv/doc_auth/welcome'

      expect(rendered).to have_link(t('idv.troubleshooting.options.supported_documents'))
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.learn_more_address_verification_options'),
      )
      expect(rendered).not_to have_link(nil, href: idv_doc_auth_return_to_sp_path)
    end
  end

  context 'with service provider' do
    let(:sp_name) { 'Example App' }

    it 'renders troubleshooting options' do
      render template: 'idv/doc_auth/welcome'

      expect(rendered).to have_link(t('idv.troubleshooting.options.supported_documents'))
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.learn_more_address_verification_options'),
      )
      expect(rendered).to have_link(
        t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
      )
    end
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:all_vendor_outage?).and_return(true)
    end

    it 'renders alert banner' do
      render template: 'idv/doc_auth/welcome'

      expect(rendered).to have_selector('.usa-alert.usa-alert--error')
    end
  end
end
