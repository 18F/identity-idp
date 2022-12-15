require 'rails_helper'

describe AbTests do
  def reload_ab_test_initializer!
    # undefine the AB tests instances so we can re-initialize them with different config values
    AbTests.constants.each do |const_name|
      AbTests.class_eval { remove_const(const_name) }
    end
    load Rails.root.join('config', 'initializers', 'ab_tests.rb').to_s
  end

  describe '::NATIVE_CAMERA' do
    let(:percent) { 30 }

    before do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize).
        and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent).
        and_return(percent)

      reload_ab_test_initializer!
    end

    after do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize).
        and_call_original
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent).
        and_call_original

      reload_ab_test_initializer!
    end

    context 'configured with buckets adding up to less than 100 percent' do
      let(:subject) { described_class::DOC_AUTH_VENDOR }
      let(:a_uuid) { SecureRandom.uuid }
      let(:b_uuid) { SecureRandom.uuid }
      before do
        allow(subject).to receive(:percent).with(a_uuid).and_return(percent)
        allow(subject).to receive(:percent).with(b_uuid).and_return(percent + 1)
      end
      it 'sorts uuids into the buckets' do
        expect(subject.bucket(a_uuid)).to eq(:alternate_vendor)
        expect(subject.bucket(b_uuid)).to eq(:default)
      end
    end
  end
end
