shared_examples 'failed idv job' do |step|
  let(:idv_job_class) do
    return Idv::ProfileJob if step == :profile
    return Idv::PhoneJob if step == :phone
  end
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

    context 'without js' do
      it 'shows a warning' do
        expect(page).to have_content t("idv.modal.#{step_locale_key}.heading")
        expect(page).to have_content t("idv.modal.#{step_locale_key}.jobfail")
        expect(page).to have_current_path(verify_session_result_path) if step == :profile
        expect(page).to have_current_path(verify_phone_result_path) if step == :phone
      end
    end

    context 'with js', :js do
      it 'shows a modal' do
        expect(page).to have_css('.modal-warning', text: t("idv.modal.#{step_locale_key}.heading"))
        expect(page).to have_css(
          '.modal-warning',
          text: strip_tags(t("idv.modal.#{step_locale_key}.jobfail"))
        )
        expect(page).to have_current_path(verify_session_result_path) if step == :profile
        expect(page).to have_current_path(verify_phone_result_path) if step == :phone
      end
    end
  end

  context 'the job times out' do
    before do
      stub_idv_job_to_timeout_in_background(idv_job_class)

      fill_out_idv_form_ok if step == :profile
      fill_out_phone_form_ok('5202691958') if step == :phone
      click_idv_continue

      Timecop.travel (Figaro.env.async_job_refresh_max_wait_seconds.to_i + 1).seconds

      visit current_path
    end

    after do
      Timecop.return
    end

    context 'without js' do
      it 'shows a warning' do
        expect(page).to have_content t("idv.modal.#{step_locale_key}.heading")
        expect(page).to have_content t("idv.modal.#{step_locale_key}.timeout")
        expect(page).to have_current_path(verify_session_result_path) if step == :profile
        expect(page).to have_current_path(verify_phone_result_path) if step == :phone
      end
    end

    context 'with js' do
      it 'shows a modal' do
        expect(page).to have_css('.modal-warning', text: t("idv.modal.#{step_locale_key}.heading"))
        expect(page).to have_css(
          '.modal-warning',
          text: strip_tags(t("idv.modal.#{step_locale_key}.timeout"))
        )
        expect(page).to have_current_path(verify_session_result_path) if step == :profile
        expect(page).to have_current_path(verify_phone_result_path) if step == :phone
      end
    end
  end

  def stub_idv_job_to_raise_error_in_background(idv_job_class)
    allow(idv_job_class).to receive(:new).and_wrap_original do |new, *args|
      idv_job = new.call(*args)
      allow(idv_job).to receive(:verify_identity_with_vendor).
        and_raise('this is a test error')
      idv_job
    end
    allow(idv_job_class).to receive(:perform_now).and_wrap_original do |perform_now, *args|
      begin
        perform_now.call(*args)
      rescue StandardError => err
        # Swallow the error so it does not get re-raised by the job
      end
    end
  end

  def stub_idv_job_to_timeout_in_background(idv_job_class)
    allow(idv_job_class).to receive(:perform_now)
  end
end
