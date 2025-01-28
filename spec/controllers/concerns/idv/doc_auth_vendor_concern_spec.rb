require 'rails_helper'

RSpec.describe Idv::DocAuthVendorConcern, :controller do
  let(:user) { create(:user) }
  let(:socure_user_set) { Idv::SocureUserSet.new }
  let(:bucket) { :mock }

  controller ApplicationController do
    include Idv::DocAuthVendorConcern
  end

  around do |ex|
    REDIS_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_POOL.with { |client| client.flushdb }
  end

  describe '#doc_auth_vendor' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:ab_test_bucket)
        .with(:DOC_AUTH_VENDOR)
        .and_return(bucket)
    end

    context 'bucket is socure' do
      let(:bucket) { :socure }

      it 'should return socure as the vendor' do
        expect(controller.doc_auth_vendor).to eq(Idp::Constants::Vendors::SOCURE)
      end

      it 'adds a user to the socure redis set' do
        expect { controller.doc_auth_vendor }.to change { socure_user_set.count }.by(1)
      end
    end
  end
end
