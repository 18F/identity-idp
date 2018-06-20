shared_examples 'failed idv job' do |step|
  let(:locale) { LinkLocaleResolver.locale }
  let(:idv_job_class) { Idv::ProoferJob }
  let(:step_locale_key) do
    return :sessions if step == :profile
    step
  end

  before do
    visit_idp_from_sp_with_loa3(:oidc)
    click_link t('links.sign_in')
    complete_idv_steps_before_step(step)
  end

  context 'the job raises an error' do
    before do
      stub_idv_job_to_raise_error_in_background(idv_job_class)

      fill_out_idv_form_ok if step == :profile
      fill_out_phone_form_ok if step == :phone
      click_idv_continue
    end

    it 'renders a jobfail failure screen' do
      expect(page).to have_current_path(session_failure_path(:jobfail)) if step == :profile
      expect(page).to have_current_path(phone_failure_path(:jobfail)) if step == :phone
      expect(page).to have_content t("idv.failure.#{step_locale_key}.heading")
      expect(page).to have_content t("idv.failure.#{step_locale_key}.jobfail")
    end
  end

  context 'the job times out' do
    before do
      stub_idv_job_to_timeout_in_background(idv_job_class)

      fill_out_idv_form_ok if step == :profile
      fill_out_phone_form_ok('5202691958') if step == :phone
      click_idv_continue

      seconds_to_travel = (Figaro.env.async_job_refresh_max_wait_seconds.to_i + 1).seconds
      Timecop.travel seconds_to_travel

      visit current_path
    end

    after do
      Timecop.return
    end

    it 'renders a timeout failure page' do
      expect(page).to have_current_path(session_failure_path(:timeout)) if step == :profile
      expect(page).to have_current_path(phone_failure_path(:timeout)) if step == :phone
      expect(page).to have_content t("idv.failure.#{step_locale_key}.heading")
      expect(page).to have_content t("idv.failure.#{step_locale_key}.timeout")
    end
  end

  # rubocop:disable Lint/HandleExceptions
  # rubocop:disable Style/RedundantBegin
  # Disabling Style/RedundantBegin because when i remove make the changes
  # to remove it, fasterer can no longer parse the code...
  def stub_idv_job_to_raise_error_in_background(idv_job_class)
    allow(Idv::Agent).to receive(:new).and_raise('this is a test error')
    allow(idv_job_class).to receive(:perform_now).and_wrap_original do |perform_now, *args|
      begin
        perform_now.call(*args)
      rescue StandardError
        # Swallow the error so it does not get re-raised by the job
      end
    end
  end
  # rubocop:enable Style/RedundantBegin
  # rubocop:enable Lint/HandleExceptions

  def stub_idv_job_to_timeout_in_background(idv_job_class)
    allow(idv_job_class).to receive(:perform_now)
  end

  def session_failure_path(reason)
    idv_session_failure_path(reason, locale: locale)
  end

  def phone_failure_path(reason)
    idv_phone_failure_path(reason, locale: locale)
  end
end
