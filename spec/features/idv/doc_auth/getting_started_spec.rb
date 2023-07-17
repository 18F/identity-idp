require 'rails_helper'

RSpec.feature 'getting started step' do
  include IdvHelper
  include DocAuthHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:maintenance_window) { [] }
  let(:sp_name) { 'Test SP' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)
    start, finish = maintenance_window
    allow(IdentityConfig.store).to receive(:acuant_maintenance_window_start).and_return(start)
    allow(IdentityConfig.store).to receive(:acuant_maintenance_window_finish).and_return(finish)

    visit_idp_from_sp_with_ial2(:oidc)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_welcome_step
    visit(idv_getting_started_url)
  end

  it 'displays expected content', :js do
    expect(page).to have_current_path(idv_getting_started_path)
  end

  context 'during the acuant maintenance window' do
    let(:maintenance_window) do
      [Time.zone.parse('2020-01-01T00:00:00Z'), Time.zone.parse('2020-01-01T23:59:59Z')]
    end
    let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }

    around do |ex|
      travel_to(now) { ex.run }
    end

    it 'renders the warning banner but no other content' do
      expect(page).to have_content('We are currently under maintenance')
      expect(page).to_not have_content(t('doc_auth.headings.welcome'))
    end
  end
end
