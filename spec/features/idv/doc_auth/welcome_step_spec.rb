require 'rails_helper'

feature 'doc auth welcome step' do
  include DocAuthHelper

  def expect_doc_auth_upload_step
    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end

  context 'button is disabled when JS is enabled', :js do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_welcome_step
    end

    it_behaves_like 'ial2 consent with js'
  end

  context 'button is clickable when JS is disabled' do
    before do
      sign_in_and_2fa_user
      complete_doc_auth_steps_before_welcome_step
    end

    def expect_doc_auth_first_step
      expect(page).to have_current_path(idv_doc_auth_welcome_step)
    end

    it_behaves_like 'ial2 consent without js'
  end

  context 'during the acuant maintenance window' do
    context 'during the acuant maintenance window' do
      let(:start) { Time.zone.parse('2020-01-01T00:00:00Z') }
      let(:now) { Time.zone.parse('2020-01-01T12:00:00Z') }
      let(:finish) { Time.zone.parse('2020-01-01T23:59:59Z') }

      before do
        allow(Figaro.env).to receive(:acuant_maintenance_window_start).and_return(start.iso8601)
        allow(Figaro.env).to receive(:acuant_maintenance_window_finish).and_return(finish.iso8601)

        sign_in_and_2fa_user
        complete_doc_auth_steps_before_welcome_step
      end

      around do |ex|
        Timecop.travel(now) { ex.run }
      end

      it 'renders the warning banner but no other content' do
        expect(page).to have_content('We are currently under maintence')
        expect(page).to_not have_content(t('doc_auth.headings.welcome'))
      end
    end
  end
end
