require 'rails_helper'

RSpec.describe 'idv/getting_started/show' do
  let(:flow_session) { {} }
  let(:user_fully_authenticated) { true }
  let(:sp_name) { nil }
  let(:user) { create(:user) }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    @sp_name = 'Login.gov'
    @title = t('doc_auth.headings.getting_started', sp_name: @sp_name)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:user_fully_authenticated?).and_return(user_fully_authenticated)
    allow(view).to receive(:user_signing_up?).and_return(false)
    allow(view).to receive(:url_for).and_wrap_original do |method, *args, &block|
      method.call(*args, &block)
    rescue
      ''
    end
    render
  end

  context 'in doc auth with an authenticated user' do
    let(:need_irs_reproofing) { false }

    before do
      allow(user).to receive(:reproof_for_irs?).and_return(need_irs_reproofing)
      assign(:current_user, user)

      render
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
      render

      expect(rendered).to have_content('We are currently under maintenance')
      expect(rendered).to_not have_content(t('doc_auth.headings.welcome'))
    end
  end

  it 'includes code to track clicks on the consent checkbox' do
    selector = [
      'lg-click-observer[event-name="IdV: consent checkbox toggled"]',
      '[name="doc_auth[ial2_consent_given]"]',
    ].join ' '

    expect(rendered).to have_css(selector)
  end

  it 'renders a link to help center article' do
    expect(rendered).to have_link(
      t('doc_auth.info.getting_started_learn_more'),
      href: help_center_redirect_path(
        category: 'verify-your-identity',
        article: 'how-to-verify-your-identity',
        flow: :idv,
        step: :getting_started,
        location: 'intro_paragraph',
      ),
    )
  end

  it 'renders a link to the privacy & security page' do
    expect(rendered).to have_link(
      t('doc_auth.getting_started.instructions.learn_more'),
      href: policy_redirect_url(flow: :idv, step: :getting_started, location: :consent),
    )
  end
end
