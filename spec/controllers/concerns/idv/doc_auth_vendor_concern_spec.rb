require 'rails_helper'

RSpec.describe Idv::DocAuthVendorConcern, :controller do
  let(:user) { create(:user) }

  controller ApplicationController do
    include DocAuthVendorConcern
  end

  describe '#doc_auth_vendor' do
    before do
      allow(ab_test).to receive(:bucket).and__return(ab_test_bucket)
    end

    context 'bucket is lexis nexis' do
    end

    context 'bucket is socure' do
    end
  end
end
