require 'rails_helper'

feature 'IdV session', :idv_job do
  include IdvStepHelper

  context 'profile job' do
    let(:idv_job_class) { Idv::ProfileJob }
    it_behaves_like 'failed idv job', :profile
  end

  context 'phone job' do
    let(:idv_job_class) { Idv::PhoneJob }
    it_behaves_like 'failed idv job', :phone
  end
end
