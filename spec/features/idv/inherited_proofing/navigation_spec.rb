require 'rails_helper'

feature 'Inherited Proofing Process', js: true do
  let(:getting_started_path) { idv_inherited_proofing_step_path(step: 'get_started') }
  let(:agreement_path) { idv_inherited_proofing_step_path(step: 'agreement') }

  context 'Continue button' do
    describe 'navigates user' do
      it "from the 'Getting Starting' page to the 'How Verifying Your Identity Works' page" do
        # Given that I am an end user on the Get Started page
        visit getting_started_path
        expect(current_path).to eq getting_started_path

        # Pressing the continue button
        click_on 'Continue'

        # Should route me to the "How verifying your identity works" page
        expect(current_path).to eq agreement_path
        expect(page).to have_css('h1', text: 'How verifying your identity works')
      end
    end
  end
end
