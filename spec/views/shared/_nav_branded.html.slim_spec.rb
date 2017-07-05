require 'rails_helper'

describe 'shared/_nav_branded.html.slim' do
  let(:view_context) { ActionController::Base.new.view_context }

  context 'with a SP-logo configured' do
    before do
      sp_with_logo = build_stubbed(
        :service_provider, logo: 'generic.svg', friendly_name: 'Best SP ever'
      )
      decorated_session = ServiceProviderSessionDecorator.new(
        sp: sp_with_logo,
        view_context: view_context,
        sp_session: {},
        service_provider_request: nil
      )
      allow(view).to receive(:decorated_session).and_return(decorated_session)
      render
    end

    it 'displays the SP logo' do
      expect(rendered).to have_css("img[alt*='Best SP ever']")
    end
  end

  context 'without a SP-logo configured' do
    before do
      sp_without_logo = build_stubbed(:service_provider, friendly_name: 'No logo no problem')
      decorated_session = ServiceProviderSessionDecorator.new(
        sp: sp_without_logo,
        view_context: view_context,
        sp_session: {},
        service_provider_request: nil
      )
      allow(view).to receive(:decorated_session).and_return(decorated_session)
      render
    end

    it 'displayes the generic  SP logo' do
      expect(rendered).to have_css("img[alt*='No logo no problem']")
    end
  end
end
