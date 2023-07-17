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
    allow_any_instance_of(Idv::WelcomeController).to receive(:getting_started_a_b_test_bucket).
      and_return(:new)

    visit_idp_from_sp_with_ial2(:oidc)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_welcome_step
  end

  it 'displays expected content', :js do
    expect(page).to have_current_path(idv_getting_started_path)

    # Try to continue with unchecked checkbox
    click_continue
    expect(page).to have_current_path(idv_getting_started_path)
    expect(page).to have_content(t('forms.validation.required_checkbox'))

    complete_getting_started_step
    expect(page).to have_current_path(idv_hybrid_handoff_path)
  end

  def complete_getting_started_step
    complete_agreement_step # it does the right thing
  end
end
