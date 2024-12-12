# frozen_string_literal: true

require 'rails_helper'
require_relative 'ux_dumper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:ux_dumper) { UxDumper.new(File.basename(__FILE__, '_spec.rb')) }

  before(:each) do
    allow_any_instance_of(ServiceProviderSession).
      to receive(:sp_name).and_return(@sp_name)
  end

  before(:all) do
    @user = user_with_2fa
    @sp_name = 'Test SP'
  end

  after(:all) do
    @user.destroy
    @sp_name = ''
  end

  context 'selfie check' do
    let(:selfie_check_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
    end

    context 'when a selfie is required by the SP' do
      context 'on mobile platform', allow_browser_log: true do
        before do
          # mock mobile device as cameraCapable, this allows us to process
          allow_any_instance_of(ActionController::Parameters).
            to receive(:[]).and_wrap_original do |impl, param_name|
            param_name.to_sym == :skip_hybrid_handoff ? '' : impl.call(param_name)
          end
        end

        context 'with a passing selfie' do
          after { ux_dumper.finish }

          it 'proceeds to the next page with valid info, including a selfie image' do
            perform_in_browser(:mobile) do
              visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
              sign_in_and_2fa_user(@user)

              ux_dumper.take_screenshot(page)

              complete_doc_auth_steps_before_document_capture_step

              ux_dumper.take_screenshot(page)

              attach_liveness_images

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
    end
  end
end
