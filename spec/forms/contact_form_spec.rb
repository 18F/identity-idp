require 'rails_helper'

describe ContactForm do
  subject { ContactForm.new }

  describe 'presence validations' do
    it 'is invalid when required attributes are not present' do
      subject.submit(email_or_tel: nil)

      expect(subject).to_not be_valid
      expect(subject.errors.full_messages.first).to eq "Email or tel can't be blank"
    end
  end
end
