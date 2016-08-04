require 'rails_helper'

describe IdvProfileForm do
  let(:user) { create(:user, :signed_up) }
  let(:subject) { IdvProfileForm.new(user) }
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666661234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66044'
    }
  end

  describe '#submit' do
    it 'returns true on success' do
      expect(subject.submit(user_attrs)).to eq true
    end

    it 'checks required fields' do
      expect(subject.submit(ssn: '1234', first_name: 'Joe')).to eq false
      expect(subject.errors).to include "#{t('idv.form.last_name')} is required"
    end

    it 'checks duplicate SSN' do
      create(:profile, ssn: '1234')

      expect(subject.submit(ssn: '1234', first_name: 'Joe')).to eq false
      expect(subject.errors).to include t('idv.errors.duplicate_ssn')
    end
  end
end
