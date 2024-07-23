# frozen_string_literal: true

require 'rails_helper'
require_relative 'ux_dumper'

RSpec.feature 'document capture step', :js, allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:ux_dumper) { UxDumper.new('mobile') }
  let(:fake_analytics) { ux_dumper.analytics }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(@sp_name)
  end

  after(:each) do
    ux_dumper.finish
  end

  before(:all) do
    @user = user_with_2fa
    @sp_name = 'Test SP'
  end

  after(:all) do
    @user.destroy
    @sp_name = ''
  end

  context 'standard mobile flow' do
    it 'proceeds to the next page with valid info' do
      perform_in_browser(:mobile) do
        visit_idp_from_oidc_sp_with_ial2

        ux_dumper.take_screenshot(page)

        sign_in_and_2fa_user(@user)

        ux_dumper.take_screenshot(page)

        complete_doc_auth_steps_before_document_capture_step

        ux_dumper.take_screenshot(page)

        attach_images(
          Rails.root.join(
            'spec', 'fixtures',
            'ial2_test_credential_no_liveness.yml'
          ),
        )

        ux_dumper.take_screenshot(page)

        submit_images

        ux_dumper.take_screenshot(page)

        fill_out_ssn_form_ok

        ux_dumper.take_screenshot(page)

        click_idv_continue

        ux_dumper.take_screenshot(page)

        complete_verify_step

        ux_dumper.take_screenshot(page)
      end
    end
  end
end
