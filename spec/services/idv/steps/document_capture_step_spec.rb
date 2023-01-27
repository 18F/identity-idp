require 'rails_helper'

describe Idv::Steps::DocumentCaptureStep do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      current_user: user,
      analytics: FakeAnalytics.new,
      url_options: {},
      request: double(
        'request',
        headers: {
          'X-Amzn-Trace-Id' => amzn_trace_id,
        },
      ),
    )
  end
  let(:amzn_trace_id) { SecureRandom.uuid }

  let(:pii_from_doc) do
    {
      ssn: '123-45-6789',
    }
  end

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = {}
    end
  end

  let(:default_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_default }
  let(:alternate_sdk_version) { IdentityConfig.store.idv_acuant_sdk_version_alternate }

  subject(:step) do
    Idv::Steps::DocumentCaptureStep.new(flow)
  end

  describe '#call' do
    it 'does not raise an exception when stored_result is nil' do
      allow(FeatureManagement).to receive(:document_capture_async_uploads_enabled?).
        and_return(false)
      allow(step).to receive(:stored_result).and_return(nil)
      step.call
    end
  end

  describe '#extra_view_variables' do
    context 'with acuant sdk upgrade A/B testing disabled' do
      let(:session_uuid) { SecureRandom.uuid }

      before do
        allow(IdentityConfig.store).
          to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
          and_return(false)

        flow.flow_session[:document_capture_session_uuid] = session_uuid
      end

      context 'and A/B test specifies the older acuant version' do
        before do
          stub_const(
            'AbTests::ACUANT_SDK',
            FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => 0) },
          )
        end

        it 'passes correct variables and acuant version when older is specified' do
          expect(subject.extra_view_variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(false)
          expect(subject.extra_view_variables[:use_alternate_sdk]).to eq(false)
          expect(subject.extra_view_variables[:acuant_version]).to eq(default_sdk_version)
        end
      end
    end

    context 'with acuant sdk upgrade A/B testing enabled' do
      let(:session_uuid) { SecureRandom.uuid }

      before do
        allow(IdentityConfig.store).
          to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
          and_return(true)

        flow.flow_session[:document_capture_session_uuid] = session_uuid
      end

      context 'and A/B test specifies the newer acuant version' do
        before do
          stub_const(
            'AbTests::ACUANT_SDK',
            FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => :use_alternate_sdk) },
          )
        end

        it 'passes correct variables and acuant version when newer is specified' do
          expect(subject.extra_view_variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
          expect(subject.extra_view_variables[:use_alternate_sdk]).to eq(true)
          expect(subject.extra_view_variables[:acuant_version]).to eq(alternate_sdk_version)
        end
      end

      context 'and A/B test specifies the older acuant version' do
        before do
          stub_const(
            'AbTests::ACUANT_SDK',
            FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => 0) },
          )
        end

        it 'passes correct variables and acuant version when older is specified' do
          expect(subject.extra_view_variables[:acuant_sdk_upgrade_a_b_testing_enabled]).to eq(true)
          expect(subject.extra_view_variables[:use_alternate_sdk]).to eq(false)
          expect(subject.extra_view_variables[:acuant_version]).to eq(default_sdk_version)
        end
      end
    end

    context 'in-person CTA variant A/B testing' do
      let(:session_uuid) { SecureRandom.uuid }
      let(:testing_enabled) { nil }
      let(:active_variant) { nil }

      before do
        allow(IdentityConfig.store).
          to receive(:in_person_cta_variant_testing_enabled).
          and_return(testing_enabled)

        flow.flow_session[:document_capture_session_uuid] = session_uuid

        stub_const(
          'AbTests::IN_PERSON_CTA',
          FakeAbTestBucket.new.tap { |ab| ab.assign(session_uuid => active_variant) },
        )
      end

      context 'with in-person CTA variant A/B testing disabled' do
        let(:testing_enabled) { false }

        context 'and A/B test specifies variant a' do
          let(:active_variant) { :in_person_variant_a }

          it 'passes the correct variables' do
            expect(
              subject.extra_view_variables[:in_person_cta_variant_testing_enabled],
            ).to eq(false)
            expect(
              subject.extra_view_variables[:in_person_cta_variant_active],
            ).to eq(:in_person_variant_a)
          end
        end
      end

      context 'with in-person CTA variant A/B testing enabled' do
        let(:testing_enabled) { true }

        context 'and A/B test specifies variant a' do
          let(:active_variant) { :in_person_variant_a }

          it 'passes the expected variables' do
            expect(subject.extra_view_variables[:in_person_cta_variant_testing_enabled]).to eq(true)
            expect(
              subject.extra_view_variables[:in_person_cta_variant_active],
            ).to eq(:in_person_variant_a)
          end
        end

        context 'and A/B test specifies variant b' do
          let(:active_variant) { :in_person_variant_b }

          it 'passes the expected variables' do
            expect(subject.extra_view_variables[:in_person_cta_variant_testing_enabled]).to eq(true)
            expect(
              subject.extra_view_variables[:in_person_cta_variant_active],
            ).to eq(:in_person_variant_b)
          end
        end

        context 'and A/B test specifies variant c' do
          let(:active_variant) { :in_person_variant_c }

          it 'passes the expected variables' do
            expect(subject.extra_view_variables[:in_person_cta_variant_testing_enabled]).to eq(true)
            expect(
              subject.extra_view_variables[:in_person_cta_variant_active],
            ).to eq(:in_person_variant_c)
          end
        end
      end
    end
  end
end
