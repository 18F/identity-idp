require 'rails_helper'

describe AttributeAsserter do
  include SamlAuthHelper

  let(:loa1_user) { create(:user, :signed_up) }
  let(:user) { create(:profile, :active, :verified).user }
  let(:identity) do
    build(
      :identity,
      service_provider: service_provider.issuer,
      session_uuid: SecureRandom.uuid
    )
  end
  let(:service_provider) do
    instance_double(
      ServiceProvider,
      issuer: 'http://localhost:3000',
      metadata: {}
    )
  end
  let(:raw_loa1_authn_request) { URI.decode sp1_authnrequest.split('SAMLRequest').last }
  let(:raw_loa3_authn_request) { URI.decode loa3_authnrequest.split('SAMLRequest').last }
  let(:loa1_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_loa1_authn_request)
  end
  let(:loa3_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_loa3_authn_request)
  end
  let(:decrypted_pii) { Pii::Attributes.new_from_hash(first_name: 'Jane') }

  describe '#build' do
    context 'verified user and LOA3 request' do
      let(:subject) do
        described_class.new(
          user: user,
          service_provider: service_provider,
          authn_request: loa3_authn_request,
          decrypted_pii: decrypted_pii
        )
      end

      context 'custom bundle includes email, phone, and first_name' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w(email phone first_name))
          subject.build
        end

        it 'includes all requested attributes + uuid' do
          expect(user.asserted_attributes.keys).
            to eq([:uuid, :email, :phone, :first_name, :verified_at])
        end

        it 'creates getter function' do
          expect(user.asserted_attributes[:first_name][:getter].call(user)).to eq 'Jane'
        end

        it 'gets UUID (MBUN) from Service Provider' do
          uuid_getter = user.asserted_attributes[:uuid][:getter]
          expect(uuid_getter.call(user)).to eq user.last_identity.uuid
        end
      end

      context 'Service Provider does not specify bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(nil)
          subject.build
        end

        context 'authn request does not specify bundle' do
          it 'only returns uuid and verified_at' do
            expect(user.asserted_attributes.keys).to eq [:uuid, :verified_at]
          end
        end

        context 'authn request specifies bundle' do
          let(:raw_loa3_authn_request) do
            URI.decode auth_request.create(loa3_with_bundle_saml_settings).split('SAMLRequest').last
          end

          it 'uses authn request bundle' do
            expect(user.asserted_attributes.keys).
              to eq([:uuid, :email, :first_name, :last_name, :ssn, :phone, :verified_at])
          end
        end
      end

      context 'Service Provider specifies empty bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return([])
          subject.build
        end

        it 'contains uuid and verified_at only' do
          expect(user.asserted_attributes.keys).to eq([:uuid, :verified_at])
        end
      end

      context 'custom bundle has invalid attribute name' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w(email foo)
          )
          subject.build
        end

        it 'silently skips invalid attribute name' do
          expect(user.asserted_attributes.keys).to eq([:uuid, :email, :verified_at])
        end
      end
    end

    context 'verified user and LOA1 request' do
      let(:subject) do
        described_class.new(
          user: user,
          service_provider: service_provider,
          authn_request: loa1_authn_request,
          decrypted_pii: decrypted_pii
        )
      end

      context 'custom bundle includes email, phone, and first_name' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w(email phone first_name))
          subject.build
        end

        it 'only includes uuid + email (no verified_at)' do
          expect(user.asserted_attributes.keys).to eq [:uuid, :email]
        end

        it 'does not create a getter function for LOA1 attributes' do
          expect(user.asserted_attributes[:email][:getter]).to eq :email
        end

        it 'gets UUID (MBUN) from Service Provider' do
          uuid_getter = user.asserted_attributes[:uuid][:getter]
          expect(uuid_getter.call(user)).to eq user.last_identity.uuid
        end
      end

      context 'Service Provider does not specify bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(nil)
          subject.build
        end

        context 'authn request does not specify bundle' do
          it 'only returns uuid' do
            expect(user.asserted_attributes.keys).to eq [:uuid]
          end
        end

        context 'authn request specifies bundle with first_name, last_name, email, ssn, phone' do
          let(:raw_loa1_authn_request) do
            URI.decode auth_request.create(loa1_with_bundle_saml_settings).split('SAMLRequest').last
          end

          it 'only returns uuid + email' do
            expect(user.asserted_attributes.keys).to eq [:uuid, :email]
          end
        end
      end

      context 'Service Provider specifies empty bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return([])
          subject.build
        end

        it 'contains UUID only' do
          expect(user.asserted_attributes.keys).to eq([:uuid])
        end
      end

      context 'custom bundle has invalid attribute name' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w(email foo)
          )
          subject.build
        end

        it 'silently skips invalid attribute name' do
          expect(user.asserted_attributes.keys).to eq([:uuid, :email])
        end
      end
    end

    shared_examples 'unverified user' do
      context 'custom bundle does not include email, phone' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w(first_name last_name)
          )
          subject.build
        end

        it 'includes only UUID' do
          expect(loa1_user.asserted_attributes.keys).to eq([:uuid])
        end
      end

      context 'custom bundle includes email, phone' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w(first_name last_name email phone)
          )
          subject.build
        end

        it 'only includes UUID and email' do
          expect(loa1_user.asserted_attributes.keys).to eq([:uuid, :email])
        end
      end
    end

    context 'unverified user and LOA3 request' do
      let(:subject) do
        described_class.new(
          user: loa1_user,
          service_provider: service_provider,
          authn_request: loa3_authn_request,
          decrypted_pii: decrypted_pii
        )
      end

      it_behaves_like 'unverified user'
    end

    context 'unverified user and LOA1 request' do
      let(:subject) do
        described_class.new(
          user: loa1_user,
          service_provider: service_provider,
          authn_request: loa1_authn_request,
          decrypted_pii: decrypted_pii
        )
      end

      it_behaves_like 'unverified user'
    end
  end
end
