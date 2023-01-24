require 'rails_helper'

describe 'StringRedacter' do
  module Idv
    class RedactTestController < ApplicationController
      include StringRedacter
    end
  end

  describe '#redact_alphanumeric' do
    it 'leaves in punctuation and spaces, but removes letters and numbers' do
      expect(Idv::RedactTestController.new.redact_alphanumeric('+11 (555) DEF-1234')).
        to eq('+## (###) XXX-####')
    end
  end
end
