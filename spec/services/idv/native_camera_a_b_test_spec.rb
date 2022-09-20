require 'rails_helper'

describe Idv::NativeCameraABTest do
  let(:percent) { 30 }

  before do
    allow(IdentityConfig.store).
      to receive(:idv_native_camera_a_b_testing_enabled).
      and_return(true)
    allow(IdentityConfig.store).
      to receive(:idv_native_camera_a_b_testing_percent).
      and_return(percent)
  end

  context 'configured with buckets adding up to less than 100 percent' do
    let(:subject) { Idv::NativeCameraABTest.new }
    let(:a_uuid) { SecureRandom.uuid }
    let(:b_uuid) { SecureRandom.uuid }
    before do
      allow_any_instance_of(AbTestBucket).to receive(:percent).with(a_uuid).and_return(percent)
      allow_any_instance_of(AbTestBucket).to receive(:percent).with(b_uuid).and_return(percent + 1)
    end
    it 'sorts uuids into the buckets' do
      expect(subject.bucket(a_uuid)).to eq(:native_camera_only)
      expect(subject.bucket(b_uuid)).to eq(:default)
    end
  end
end
