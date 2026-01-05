require 'rails_helper'

RSpec.describe PivCacConfiguration do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'name validations' do
    it 'is invalid when name is longer than 20 characters' do
      # binding.pry
      config = PivCacConfiguration.new(
        name: 'a' * 21,
      )

      expect(config).not_to be_valid
    end

    it('is valid when name has exactly 20 characters') do
      config = PivCacConfiguration.new(
        name: 'a' * 20,
      )

      expect(config).to be_valid
    end
  end
end
