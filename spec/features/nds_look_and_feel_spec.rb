require 'rails_helper'

RSpec.feature 'NDS look and feel experiment' do
  before do
    allow(IdentityConfig.store).to receive(:nds_look_and_feel_percent).and_return(50)
    reload_ab_tests
    allow(SecureRandom).to receive(:uuid).and_return('experiment-uuid')
    stub_const(
      'AbTests::NDS_LOOK_AND_FEEL',
      instance_double(
        AbTest,
        bucket:,
        include_in_analytics_event?: true,
      ),
    )
  end

  context 'when the generated experiment UUID is in the NDS bucket' do
    let(:bucket) { :nds }

    scenario 'the first page load uses the NDS layout and stores the UUID' do
      visit root_path

      expect(page).to have_css('link[href*="nds_application"]', visible: :all)
      expect(page.driver.browser.rack_mock_session.cookie_jar[:nds_experiment_uuid])
        .to eq('experiment-uuid')
    end
  end

  context 'when the generated experiment UUID is in the legacy bucket' do
    let(:bucket) { :default }

    scenario 'the first page load uses the legacy layout and stores the UUID' do
      visit root_path

      expect(page).to have_css('.site-wrap.bg-primary-lighter')
      expect(page).not_to have_css('link[href*="nds_application"]', visible: :all)
      expect(page.driver.browser.rack_mock_session.cookie_jar[:nds_experiment_uuid])
        .to eq('experiment-uuid')
    end
  end
end
