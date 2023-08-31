require 'rails_helper'

RSpec.describe 'StringRedacter' do
  describe '#redact_alphanumeric' do
    it 'leaves in punctuation and spaces, but removes letters and numbers' do
      expect(StringRedacter.redact_alphanumeric('+11 (555) DEF-1234')).
        to eq('+## (###) XXX-####')
    end
  end
end
