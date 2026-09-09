require 'rails_helper'

RSpec.feature 'NDS look and feel experiment' do
  let(:experiment_uuid_cookie) do
    page.driver.browser.rack_mock_session.cookie_jar['nds_experiment_uuid']
  end

  before do
    stub_const(
      'AbTests::NDS_LOOK_AND_FEEL',
      instance_double(
        AbTest,
        bucket:,
        experiment: 'NDS Look and Feel Phase 1',
        include_in_analytics_event?: true,
      ),
    )
  end

  context 'when the generated experiment UUID is in the NDS bucket' do
    let(:bucket) { :nds }

    scenario 'the first page load uses the NDS layout and stores the UUID' do
      visit root_path

      expect(page).to have_css('link[href*="nds_application"]', visible: :all)
      expect(experiment_uuid_cookie).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end
  end

  context 'when the generated experiment UUID is in the legacy bucket' do
    let(:bucket) { :default }

    scenario 'the first page load uses the legacy layout and stores the UUID' do
      visit root_path

      expect(page).to have_css('.site-wrap.bg-primary-lighter')
      expect(page).not_to have_css('link[href*="nds_application"]', visible: :all)
      expect(experiment_uuid_cookie).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    end
  end
end
