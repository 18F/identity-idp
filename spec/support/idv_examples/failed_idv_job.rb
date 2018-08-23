shared_examples 'failed idv job' do |step|
  let(:locale) { LinkLocaleResolver.locale }
  let(:step_locale_key) do
    return :sessions if step == :profile
    step
  end

  before do
    visit_idp_from_sp_with_loa3(:oidc)
    click_link t('links.sign_in')
    complete_idv_steps_before_step(step)
  end

  context 'the proofer raises an error' do
    before do
      stub_idv_proofers_to_raise_error_in_background

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

  def stub_idv_proofers_to_raise_error_in_background
    proofer = instance_double(ResolutionMock)
    allow(ResolutionMock).to receive(:new).and_return(proofer)
    allow(AddressMock).to receive(:new).and_return(proofer)
    allow(proofer).to receive(:class).and_return(ResolutionMock)

    result = Proofer::Result.new(exception: RuntimeError.new('this is a test error'))
    allow(proofer).to receive(:proof).and_return(result)
  end

  def session_failure_path(reason)
    idv_session_failure_path(reason, locale: locale)
  end

  def phone_failure_path(reason)
    idv_phone_failure_path(reason, locale: locale)
  end
end
