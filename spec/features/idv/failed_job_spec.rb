require 'rails_helper'

feature 'IdV session', :idv_job do
  include IdvStepHelper

  context 'profile job' do
    let(:idv_job_class) { Idv::ProfileJob }

    alias complete_previous_idv_steps start_idv_at_profile_step

    it_behaves_like 'failed idv job', :sessions
  end

  context 'phone job' do
    let(:idv_job_class) { Idv::PhoneJob }

    alias complete_previous_idv_steps complete_idv_steps_before_phone_step

    it_behaves_like 'failed idv job', :phone
  end
end
