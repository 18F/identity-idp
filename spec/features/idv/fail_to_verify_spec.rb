require 'rails_helper'

feature 'fail to verify', :idv_job do
  include IdvStepHelper

  it_behaves_like 'fail to verify idv info', :profile
  it_behaves_like 'fail to verify idv info', :phone
end
