require 'rails_helper'

RSpec.describe 'Approving Pending IPP Enrollments' do
  context 'when Rails env is not development' do
    it 'renders not found' do
      allow(Rails.env).to receive(:development?).and_return(false)

      first_user = create(
        :user, :with_phone, :with_pending_in_person_enrollment, password: 'p@assword!'
      )
      create(
        :user, :with_phone, :with_pending_in_person_enrollment, password: 'p@assword!'
      )

      sign_in_and_2fa_user(first_user)
      visit test_ipp_path

      expect(page).not_to have_content(first_user.uuid)
      expect(page).to have_content '404'
    end
  end

  context 'when Rails env is development' do
    it 'shows all pending enrollments' do
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
