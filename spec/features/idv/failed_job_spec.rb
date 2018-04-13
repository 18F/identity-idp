require 'rails_helper'

feature 'IdV session', :idv_job do
  include IdvStepHelper

  context 'profile job' do
    it_behaves_like 'failed idv job', :profile
  end
end
