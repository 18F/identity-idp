require 'rails_helper'

RSpec.feature 'NDS look and feel experiment' do
  before do
    # The experiment UUID cookie is permanent and short-circuits generation, so a
    # cookie left over from an earlier example in this shard would mask the
    # stubbed UUID. Start every scenario from an empty jar.
    Capybara.reset_sessions!
    allow(IdentityConfig.store).to receive(:nds_look_and_feel_percent).and_return(50)
    reload_ab_tests
    allow(SecureRandom).to receive(:uuid).and_return('experiment-uuid')
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

  context 'when a user in the NDS bucket opts out via the footer' do
    let(:bucket) { :nds }

    scenario 'switches to the legacy layout and persists the opt-out' do
      visit root_path
      expect(page).to have_css('link[href*="nds_application"]', visible: :all)

      click_button t('nds.footer.switch_to_legacy')

      expect(page).to have_current_path(root_path)
      expect(page).not_to have_css('link[href*="nds_application"]', visible: :all)
      expect(
        AbTestAssignment.bucket(
          experiment: 'NDS Look and Feel Phase 1',
          discriminator: 'experiment-uuid',
        ),
      ).to eq(:opt_out)

      visit root_path
      expect(page).not_to have_css('link[href*="nds_application"]', visible: :all)
    end
  end
end
