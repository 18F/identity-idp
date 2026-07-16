require 'rails_helper'

RSpec.describe 'idv/welcome/show.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user) }
  let(:sp_session) { {} }
  let(:view_context) { ActionController::Base.new.view_context }
  let(:sp) { build(:service_provider) }

  before do
    allow(view_context).to receive(:current_user).and_return(user)
    allow(view).to receive(:current_sp).and_return(sp)

    decorated_sp_session = ServiceProviderSession.new(
      sp: sp,
      view_context: view_context,
      sp_session: sp_session,
      service_provider_request: nil,
    )
    presenter = Idv::WelcomePresenter.new(decorated_sp_session:)
    assign(:presenter, presenter)
    assign(:current_user, user)
    render
  end

  context 'in doc auth with an authenticated user' do
    it 'renders exit and continue actions' do
      expect(rendered).to have_link(t('idv.buttons.phone.no_us_phone_number'))
      expect(rendered).to have_button(t('doc_auth.buttons.continue'))
    end

    it 'renders the welcome template' do
      expect(rendered).to have_content(
        t('headings.identity_verification_intro.title', sp: sp.friendly_name),
      )
      expect(rendered).to have_content(
        t('headings.identity_verification_intro.intro', sp: sp.friendly_name),
      )
      expect(rendered).to have_content(
        t('headings.identity_verification_intro.what_youll_need'),
      )
      expect(rendered).to have_content(
        t('headings.identity_verification_intro.requirement_id_title'),
      )
      expect(rendered).to have_content(
        t('headings.identity_verification_intro.protect_data_heading'),
      )
    end
  end
end
