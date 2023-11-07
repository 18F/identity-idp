require 'rails_helper'

RSpec.describe UpdateEmailLanguageForm do
  let(:user) { build(:user) }

  subject(:form) { UpdateEmailLanguageForm.new(user) }

  describe '#submit' do
    subject(:submit) { form.submit(email_language:) }

    context 'with a valid email_language' do
      let(:email_language) { 'es' }

      it 'is valid and has no errors' do
        response = submit

        expect(form).to be_valid
        expect(form.errors).to be_blank
        expect(response).to be_success
        expect(response.errors).to be_blank
      end

      it 'updates the user email_language' do
        expect { submit }.to(change { user.email_language }.to('es'))
      end
    end

    context 'with an supported email_language' do
      let(:email_language) { 'zz' }

      it 'is invalid' do
        response = submit

        expect(form).to_not be_valid
        expect(form.errors).to be_present
        expect(response).to_not be_success
        expect(response.errors).to be_present
      end

      it 'does not update the user email_language' do
        expect { submit }.to_not(change { user.email_language })
      end
    end
  end
end
