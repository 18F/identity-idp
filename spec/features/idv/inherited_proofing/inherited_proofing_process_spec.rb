require 'rails_helper'

feature 'Inherited Proofing Process', js: true do
  include IdvStepHelper

  let(:inherited_proofing_enabled) { true }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp) { :getting_started }
  let(:user) { user_with_2fa }

 # start on get started page
 # find continue button
 # click button
 # end on how verifying your identity works page

 describe "basic navigation" do
  it "navigates from the 'Getting Starting' page to the 'How Verifying Your Identity Works' page" do
    visit idv_inherited_proofing_step_path(step: 'getting_started')
    click_on "Continue"
    save_and_open_page
  end
 end
end