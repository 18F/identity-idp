require 'rails_helper'

describe PwnedPasswords::LookupPassword do
  describe '#call' do
    let(:pwned_passwords) do
      %w[
        3.1415926535
        3.14159265358
        3.141592653589
        3.1415926535897
        3.14159265358979
        3.141592653589793
        3.1415926535897932
        3.14159265358979323
        3.141592653589793238
        3.1415926535897932384
      ]
    end
    let(:good_passwords) do
      %w[
        pepperpickles
        saltypickles
      ]
    end

    it 'returns false for pwned passwords' do
      pwned_passwords.each do |password|
        expect(PwnedPasswords::LookupPassword.call(password)).to be true
      end
    end

    it 'returns true for non pwned passwords' do
      good_passwords.each do |password|
        expect(PwnedPasswords::LookupPassword.call(password)).to be false
      end
    end
  end
end
