require 'rails_helper'

feature 'doc auth welcome step' do
  include DocAuthHelper

  def expect_doc_auth_upload_step
    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end

  context 'skipping upload step', :js, driver: :headless_chrome_mobile do
    let(:fake_analytics) { FakeAnalytics.new }

    before do
      allow_any_instance_of(ApplicationController).
        to receive(:analytics).and_return(fake_analytics)

      sign_in_and_2fa_user
      complete_doc_auth_steps_before_welcome_step
      click_continue
    end

    it 'progresses to the agreement screen' do
      expect(page).to have_current_path(idv_doc_auth_agreement_step)
    end
  end

  context 'during the acuant maintenance window' do
    context 'during the acuant maintenance window' do
      let(:start) { Time.zone.parse('2020-01-01T00:00:00Z') }
      let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }
      let(:finish) { Time.zone.parse('2020-01-01T23:59:59Z') }

      before do
        allow(AppConfig.env).to receive(:acuant_maintenance_window_start).and_return(
          start.iso8601,
        )
        allow(AppConfig.env).to receive(:acuant_maintenance_window_finish).and_return(
          finish.iso8601,
        )

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_welcome_step
      end

      around do |ex|
        Timecop.travel(now) { ex.run }
      end

      it 'renders the warning banner but no other content' do
        expect(page).to have_content('We are currently under maintenance')
        expect(page).to_not have_content(t('doc_auth.headings.welcome'))
      end
    end
  end
end
