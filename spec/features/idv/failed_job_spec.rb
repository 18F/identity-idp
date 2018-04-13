require 'rails_helper'

feature 'IdV session', :idv_job do
  include IdvStepHelper

  context 'phone job' do
    it_behaves_like 'failed idv job', :phone
  end
end
