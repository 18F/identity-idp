require 'rails_helper'

describe Proofing::Aamva::Result do
  it 'returns AAMVA metadata'

  context 'a successful response' do
    it 'contains a successful result'

    it 'contains address failures if the address fails'
  end

  context 'failed to match response' do
    it 'contains a failed result and information about failed attributes'
  end

  context 'an error repsonse' do
    it 'contains error information'
  end
end
