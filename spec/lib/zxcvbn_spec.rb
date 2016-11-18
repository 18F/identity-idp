require 'rails_helper'
require "#{Rails.root}/lib/zxcvbn_tester"

describe Zxcvbn do
  describe '#src' do
    it 'defaults to library from npm' do
      default = File.expand_path("#{Rails.root}/node_modules/zxcvbn/dist/zxcvbn.js", __FILE__)

      data_path = Zxcvbn::Tester.new.data_path

      expect(data_path).to eq default
    end
  end
end
