require 'rails_helper'

describe Zxcvbn do
  describe '#src' do
    it 'defaults to library from npm' do
      default = Rails.root.join('node_modules', 'zxcvbn', 'dist', 'zxcvbn.js')

      data_path = Zxcvbn::Tester.new.data_path

      expect(data_path).to eq default
    end
  end
end
