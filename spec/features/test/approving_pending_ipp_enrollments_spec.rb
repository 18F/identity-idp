require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'Approving Pending IPP Enrollments' do
  context 'when Rails env is not development and allow_ipp_enrollment_approval? is true' do
    it 'only shows pending enrollments for the current user', allow_browser_log: true do
      allow(FeatureManagement).to receive(:allow_ipp_enrollment_approval?).and_return(true)
      first_user = create(
        :user, :with_phone, :with_pending_in_person_enrollment, password: 'p@assword!'
      )
      second_user = create(
        :user, :with_phone, :with_pending_in_person_enrollment, password: 'p@assword!'
      )

      sign_in_and_2fa_user(first_user)
      visit test_ipp_path

      expect(page).to have_content(first_user.uuid)
      expect(page).not_to have_content(second_user.uuid)
    end
  end

  context 'when Rails env is development and allow_ipp_enrollment_approval? is true' do
    it 'shows all pending enrollments', allow_browser_log: true do
      allow(FeatureManagement).to receive(:allow_ipp_enrollment_approval?).and_return(true)
      allow(Rails.env).to receive(:development?).and_return(true)

      first_user = create(
        :user, :with_phone, :with_pending_in_person_enrollment, password: 'p@assword!'
      )
      second_user = create(
        :user, :with_phone, :with_pending_in_person_enrollment, password: 'p@assword!'
      )

      sign_in_and_2fa_user(second_user)
      visit test_ipp_path

      expect(page).to have_content(first_user.uuid)
      expect(page).to have_content(second_user.uuid)
    end
  end
end
