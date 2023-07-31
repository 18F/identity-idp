require 'rails_helper'
RSpec.feature 'phone errors', :js do
  include IdvStepHelper
  include IdvHelper

  it_behaves_like 'phone errors without submitted phone number'
end