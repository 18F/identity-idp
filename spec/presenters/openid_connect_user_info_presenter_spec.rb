require 'rails_helper'

RSpec.describe OpenidConnectUserInfoPresenter do
  include Rails.application.routes.url_helpers

  let(:rails_session_id) { SecureRandom.uuid }
  let(:scope) do
    'openid email all_emails address phone profile social_security_number x509'
  end
  let(:service_provider_ial) { 2 }
  let(:service_provider) { create(:service_provider, ial: service_provider_ial) }
  let(:profile) { create(:profile, :active, :verified) }
  let(:identity) do
    build(
      :service_provider_identity,
      rails_session_id: rails_session_id,
      user: create(:user, profiles: [profile]),
      service_provider: service_provider.issuer,
      scope: scope,
      aal: 2,
      requested_aal_value: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
    )
  end

  subject(:presenter) { OpenidConnectUserInfoPresenter.new(identity) }

  describe '#user_info' do
    subject(:user_info) { presenter.user_info }

    context 'without a vtr parameter' do
      context 'basic ial1' do
        it 'has basic attributes' do
          ial = Saml::Idp::Constants::AUTHN_CONTEXT_IAL_TO_CLASSREF[identity.ial]
          aal = Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF

          aggregate_failures do
            expect(user_info[:sub]).to eq(identity.uuid)
            expect(user_info[:iss]).to eq(root_url)
            expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
            expect(user_info[:email_verified]).to eq(true)
            expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
            expect(user_info[:ial]).to eq(ial)
            expect(user_info[:aal]).to eq(aal)
            expect(user_info).not_to have_key(:vot)
          end
        end
      end

      context 'ialmax' do
        let(:ial) { Idp::Constants::IAL_MAX }
        let(:ial_value) { Saml::Idp::Constants::AUTHN_CONTEXT_IAL_TO_CLASSREF[ial] }
        let(:aal) { Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF }
        before { identity.ial = ial }

        it 'has basic attributes' do
          aggregate_failures do
            expect(user_info[:sub]).to eq(identity.uuid)
            expect(user_info[:iss]).to eq(root_url)
            expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
            expect(user_info[:email_verified]).to eq(true)
            expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
            expect(user_info[:ial]).to eq(ial_value)
            expect(user_info[:aal]).to eq(aal)
            expect(user_info).not_to have_key(:vot)
          end
        end

        it 'does not return ial2 attributes' do
          aggregate_failures do
            expect(user_info[:given_name]).to eq(nil)
            expect(user_info[:family_name]).to eq(nil)
            expect(user_info[:birthdate]).to eq(nil)
            expect(user_info[:phone]).to eq(nil)
            expect(user_info[:phone_verified]).to eq(nil)
            expect(user_info[:address]).to eq(nil)
            expect(user_info).not_to have_key(:vot)
          end
        end
      end

      context 'when a piv/cac was used as second factor' do
        let(:x509_subject) { 'x509-subject' }
        let(:presented) { true }
        let(:issuer) { 'trusted issuer' }

        let(:x509) do
          X509::Attributes.new_from_hash(
            subject: x509_subject,
            presented:,
            issuer:,
          )
        end

        before do
          OutOfBandSessionAccessor.new(rails_session_id).put_x509(x509, 5.minutes.to_i)
        end

        context 'when the identity has piv/cac associated' do
          let(:identity) do
            build(
              :service_provider_identity,
              rails_session_id: rails_session_id,
              user: create(:user, :with_piv_or_cac),
              scope: scope,
            )
          end

          context 'when the scope includes all attributes' do
            it 'returns x509 attributes' do
              aggregate_failures do
                expect(user_info[:x509_subject]).to eq(x509_subject)
                expect(user_info[:x509_presented]).to eq(presented)
                expect(user_info[:x509_issuer]).to eq(issuer)
              end
            end

            it 'renders values as simple strings as json' do
              json = user_info.as_json

              expect(json['x509_subject']).to eq(x509_subject)
              expect(json['x509_presented']).to eq(presented)
              expect(json['x509_issuer']).to eq(issuer)
            end
          end

          context 'when the sp requested x509_presented scope before it was fixed to string' do
            before do
              expect(IdentityConfig.store).to receive(
                :x509_presented_hash_attribute_requested_issuers,
              ).
                and_return([identity.service_provider])
            end

            it 'returns x509_presented as an (X509::Attribute' do
              # This is guarding against partners who may have coded against
              # a bug where we returning the wrong data type for x509_presented
              aggregate_failures do
                expect(user_info[:x509_subject]).to eq(x509_subject)
                expect(user_info[:x509_presented].class).to eq(X509::Attribute)
                expect(user_info[:x509_issuer]).to eq(issuer)
              end
            end
          end
        end

        context 'when the identity has no piv/cac associated' do
          context 'when the scope includes all attributes' do
            it 'returns no x509 attributes' do
              aggregate_failures do
                expect(user_info[:x509_subject]).to be_blank
                expect(user_info[:x509_issuer]).to be_blank
                expect(user_info[:x509_presented]).to be false
              end
            end
          end
        end
      end

      context 'when there is decrypted ial2 session data in redis' do
        let(:pii) do
          {
            first_name: 'John',
            last_name: 'Smith',
            dob: '12/31/1970',
            address1: '123 Fake St',
            address2: 'Apt 456',
            city: 'Washington',
            state: 'DC',
            zipcode: '  12345-1234',
            phone: '(703) 555-5555',
            ssn: '666661234',
          }
        end

        before do
          OutOfBandSessionAccessor.new(rails_session_id).put_pii(
            profile_id: profile.id,
            pii: pii,
            expiration: 5.minutes.to_i,
          )
        end

        context 'when the identity has ial2 access' do
          before { identity.ial = Idp::Constants::IAL2 }

          context 'when the scope includes all attributes' do
            it 'returns ial2 attributes' do
              aggregate_failures do
                expect(user_info[:given_name]).to eq('John')
                expect(user_info[:family_name]).to eq('Smith')
                expect(user_info[:birthdate]).to eq('1970-12-31')
                expect(user_info[:phone]).to eq('+17035555555')
                expect(user_info[:phone_verified]).to eq(true)
                expect(user_info[:address]).to eq(
                  formatted: "123 Fake St\nApt 456\nWashington, DC 12345",
                  street_address: "123 Fake St\nApt 456",
                  locality: 'Washington',
                  region: 'DC',
                  postal_code: '12345',
                )
                expect(user_info[:verified_at]).to eq(profile.verified_at.to_i)
                expect(user_info[:social_security_number]).to eq('666661234')
              end
            end

            it 'renders values as simple strings as json' do
              json = user_info.as_json

              expect(json['given_name']).to eq('John')
            end
          end

          context 'when the scope only includes minimal attributes' do
            let(:scope) { 'openid email phone' }

            it 'returns attributes allowed by the scope' do
              aggregate_failures do
                expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
                expect(user_info[:email_verified]).to eq(true)
                expect(user_info[:given_name]).to eq(nil)
                expect(user_info[:family_name]).to eq(nil)
                expect(user_info[:birthdate]).to eq(nil)
                expect(user_info[:phone]).to eq('+17035555555')
                expect(user_info[:phone_verified]).to eq(true)
                expect(user_info[:address]).to eq(nil)
                expect(user_info[:verified_at]).to eq(nil)
                expect(user_info[:social_security_number]).to eq(nil)
              end
            end
          end

          context 'verified_at' do
            let(:scope) { 'openid profile:verified_at' }

            context 'when the service provider has ial1 access' do
              let(:service_provider_ial) { 1 }

              it 'does not provide verified_at' do
                expect(user_info[:verified_at]).to eq(nil)
              end
            end

            context 'when the service provider has ial2 access' do
              let(:service_provider_ial) { 2 }

              it 'provides verified_at' do
                expect(user_info[:verified_at]).to eq(profile.verified_at.to_i)
              end
            end
          end
        end

        context 'when the identity only has ial1 access' do
          before { identity.ial = Idp::Constants::IAL1 }

          it 'does not return ial2 attributes' do
            aggregate_failures do
              expect(user_info[:given_name]).to eq(nil)
              expect(user_info[:family_name]).to eq(nil)
              expect(user_info[:birthdate]).to eq(nil)
              expect(user_info[:phone]).to eq(nil)
              expect(user_info[:phone_verified]).to eq(nil)
              expect(user_info[:address]).to eq(nil)
            end
          end
        end

        context 'when the identity has ialmax access' do
          before { identity.ial = Idp::Constants::IAL_MAX }

          context 'when the scope includes all attributes' do
            it 'returns ial2 attributes' do
              aggregate_failures do
                expect(user_info[:given_name]).to eq('John')
                expect(user_info[:family_name]).to eq('Smith')
                expect(user_info[:birthdate]).to eq('1970-12-31')
                expect(user_info[:phone]).to eq('+17035555555')
                expect(user_info[:phone_verified]).to eq(true)
                expect(user_info[:address]).to eq(
                  formatted: "123 Fake St\nApt 456\nWashington, DC 12345",
                  street_address: "123 Fake St\nApt 456",
                  locality: 'Washington',
                  region: 'DC',
                  postal_code: '12345',
                )
                expect(user_info[:verified_at]).to eq(profile.verified_at.to_i)
                expect(user_info[:social_security_number]).to eq('666661234')
              end
            end

            it 'renders values as simple strings as json' do
              json = user_info.as_json

              expect(json['given_name']).to eq('John')
            end
          end

          context 'when the scope only includes minimal attributes' do
            let(:scope) { 'openid email phone' }

            it 'returns attributes allowed by the scope' do
              aggregate_failures do
                expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
                expect(user_info[:email_verified]).to eq(true)
                expect(user_info[:given_name]).to eq(nil)
                expect(user_info[:family_name]).to eq(nil)
                expect(user_info[:birthdate]).to eq(nil)
                expect(user_info[:phone]).to eq('+17035555555')
                expect(user_info[:phone_verified]).to eq(true)
                expect(user_info[:address]).to eq(nil)
                expect(user_info[:verified_at]).to eq(nil)
                expect(user_info[:social_security_number]).to eq(nil)
              end
            end
          end
        end
      end
    end

    context 'with a vtr parameter' do
      let(:identity) do
        build(
          :service_provider_identity,
          rails_session_id: rails_session_id,
          user: create(:user, profiles: [profile]),
          service_provider: service_provider.issuer,
          scope: scope,
          aal: 2,
          vtr: ['C1'],
        )
      end

      it 'has basic attributes' do
        aggregate_failures do
          expect(user_info[:sub]).to eq(identity.uuid)
          expect(user_info[:iss]).to eq(root_url)
          expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
          expect(user_info[:email_verified]).to eq(true)
          expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
          expect(user_info).not_to have_key(:ial)
          expect(user_info).not_to have_key(:aal)
          expect(user_info[:vot]).to eq('C1')
          expect(user_info[:vtm]).to eq(IdentityConfig.store.vtm_url)
        end
      end
    end
  end
end
