require 'rails_helper'

RSpec.describe Idv::ProofingComponents do
  let(:user) { create(:user) }

  let(:user_session) { {} }

  let(:session) { {} }

  let(:idv_session) do
    Idv::Session.new(
      current_user: user,
      user_session:,
      service_provider: nil,
    ).tap do |idv_session|
      idv_session.pii_from_doc = pii_from_doc
    end
  end

  let(:pii_from_doc) { nil }

  subject do
    described_class.new(
      idv_session:,
    )
  end

  describe '#to_h' do
    let(:pii_from_doc) { Idp::Constants::MOCK_IDV_APPLICANT }

    before do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return('test_vendor')
      idv_session.mark_verify_info_step_complete!
      idv_session.address_verification_mechanism = 'gpo'
      allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?)
        .and_return(true)
      idv_session.threatmetrix_review_status = 'pass'
      idv_session.source_check_vendor = 'aamva'
      idv_session.resolution_vendor = 'lexis_nexis'
    end

    it 'returns expected result' do
      expect(subject.to_h).to eql(
        {
          document_check: 'test_vendor',
          document_type: 'state_id',
          source_check: 'aamva',
          resolution_check: 'lexis_nexis',
          address_check: 'gpo_letter',
          threatmetrix: true,
          threatmetrix_review_status: 'pass',
        },
      )
    end
  end

  describe '#document_check' do
    it 'returns nil by default' do
      expect(subject.document_check).to be_nil
    end

    context 'in-person proofing' do
      context 'establishing' do
        let!(:enrollment) { create(:in_person_enrollment, :establishing, user:) }

        it 'returns USPS' do
          expect(subject.document_check).to eql(Idp::Constants::Vendors::USPS)
        end
      end

      context 'pending' do
        let!(:enrollment) { create(:in_person_enrollment, :pending, user:) }

        it 'returns USPS' do
          expect(subject.document_check).to eql(Idp::Constants::Vendors::USPS)
        end
      end
    end

    context 'doc auth' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return('test_vendor')
      end

      context 'before doc auth complete' do
        it 'returns nil' do
          expect(subject.document_check).to be_nil
        end
      end

      context 'after doc auth completed successfully' do
        let(:pii_from_doc) { Idp::Constants::MOCK_IDV_APPLICANT }

        it 'returns doc auth vendor' do
          expect(subject.document_check).to eql('test_vendor')
        end
      end
    end
  end

  describe '#document_type' do
    context 'in-person proofing' do
      context 'establishing' do
        let!(:enrollment) { create(:in_person_enrollment, :establishing, user:) }

        it 'returns nil' do
          expect(subject.document_type).to be_nil
        end
      end

      context 'pending' do
        let!(:enrollment) { create(:in_person_enrollment, :pending, user:) }

        it 'returns nil' do
          expect(subject.document_type).to be_nil
        end
      end
    end

    context 'doc auth' do
      context 'before doc auth complete' do
        it 'returns nil' do
          expect(subject.document_type).to be_nil
        end
      end

      context 'after doc auth completed successfully' do
        let(:pii_from_doc) { Idp::Constants::MOCK_IDV_APPLICANT }

        it 'returns doc auth vendor' do
          expect(subject.document_type).to eql('state_id')
        end
      end
    end
  end

  describe '#source_check' do
    it 'returns nil by default' do
      expect(subject.source_check).to be_nil
    end

    context 'after verification' do
      before do
        idv_session.mark_verify_info_step_complete!
        idv_session.source_check_vendor = 'aamva'
      end

      it 'returns aamva' do
        expect(subject.source_check).to eql(Idp::Constants::Vendors::AAMVA)
      end
    end
  end

  describe '#residential_resolution_check' do
    it 'returns nil by default' do
      expect(subject.residential_resolution_check).to be_nil
    end

    context 'when resolution_vendor is set on idv_session' do
      before do
        idv_session.mark_verify_info_step_complete!
        idv_session.residential_resolution_vendor = 'AReallyGoodVendor'
      end

      it 'returns the vendor we set' do
        expect(subject.residential_resolution_check).to eql('AReallyGoodVendor')
      end
    end
  end

  describe '#resolution_check' do
    it 'returns nil by default' do
      expect(subject.resolution_check).to be_nil
    end

    context 'when resolution_vendor is set on idv_session' do
      before do
        idv_session.mark_verify_info_step_complete!
        idv_session.resolution_vendor = 'AReallyGoodVendor'
      end

      it 'returns the vendor we set' do
        expect(subject.resolution_check).to eql('AReallyGoodVendor')
      end
    end
  end

  describe '#address_check' do
    it 'returns nil by default' do
      expect(subject.address_check).to be_nil
    end

    context 'in GPO flow' do
      before do
        idv_session.address_verification_mechanism = 'gpo'
      end

      it 'returns gpo_letter' do
        expect(subject.address_check).to eql('gpo_letter')
      end
    end

    context 'using phone verification' do
      before do
        idv_session.mark_phone_step_started!
      end

      it 'returns lexis_nexis_address' do
        expect(subject.address_check).to eql('lexis_nexis_address')
      end
    end
  end

  describe '#threatmetrix' do
    context 'device profiling collecting enabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?)
          .and_return(true)
      end

      context 'threatmetrix_review_status present' do
        before do
          idv_session.threatmetrix_review_status = 'pass'
        end

        it 'returns true' do
          expect(subject.threatmetrix).to be_truthy
        end
      end

      context 'threatmetrix_review_status not present' do
        it 'returns nil' do
          expect(subject.threatmetrix).to be_nil
        end
      end
    end

    context 'device profiling collecting disabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?)
          .and_return(false)
      end

      context 'threatmetrix_review_status present' do
        before do
          idv_session.threatmetrix_review_status = 'pass'
        end

        it 'returns false' do
          expect(subject.threatmetrix).to eql(false)
        end
      end

      context 'threatmetrix_review_status not present' do
        it 'returns nil' do
          expect(subject.threatmetrix).to be_nil
        end
      end
    end
  end

  describe '#threatmetrix_review_status' do
    context 'threatmetrix_review_status present in idv_session' do
      before do
        idv_session.threatmetrix_review_status = 'pass'
      end

      it 'returns value' do
        expect(subject.threatmetrix_review_status).to eql('pass')
      end
    end

    context 'threatmetrix_review_status not present in idv_session' do
      it 'returns nil' do
        expect(subject.threatmetrix_review_status).to be_nil
      end
    end
  end
end
