require 'rails_helper'

describe SamlRequestPresenter do
  describe '#requested_attributes' do
    context 'IAL1 and bundle contains invalid attributes and IAL2 attributes' do
      it 'only returns :email' do
        request = instance_double(FakeSamlRequest)
        allow(FakeSamlRequest).to receive(:new).and_return(request)
        allow(request).to receive(:requested_authn_contexts).
          and_return([Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF])
        allow(request).to receive(:requested_authn_context_comparison).and_return('exact')
        allow(request).to receive(:requested_ial_authn_context).
          and_return(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        all_attributes = %w[
          email all_emails first_name last_name dob ssn verified_at
          phone address1 address2 city state zipcode foo
        ]
        service_provider = ServiceProvider.new(attribute_bundle: all_attributes)
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)

        expect(presenter.requested_attributes).to eq(%i[email all_emails verified_at])
      end
    end

    context 'with no requested context and IAL2 SP' do
      it 'returns SP attribute_bundle' do
        request = instance_double(FakeSamlRequest)
        allow(FakeSamlRequest).to receive(:new).and_return(request)
        allow(request).to receive(:requested_authn_contexts).
          and_return([])
        allow(request).to receive(:requested_authn_context_comparison).and_return('exact')
        allow(request).to receive(:requested_ial_authn_context).
          and_return(nil)

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        sp_attributes = %w[email first_name last_name ssn zipcode]
        service_provider = ServiceProvider.new(attribute_bundle: sp_attributes, ial: 2)
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)

        expect(presenter.requested_attributes).to eq(
          %i[email given_name family_name social_security_number address],
        )
      end
    end

    context 'with no requested context and IAL1 SP' do
      it 'returns permitted attribute_bundle' do
        request = instance_double(FakeSamlRequest)
        allow(FakeSamlRequest).to receive(:new).and_return(request)
        allow(request).to receive(:requested_authn_contexts).
          and_return([])
        allow(request).to receive(:requested_authn_context_comparison).and_return('exact')
        allow(request).to receive(:requested_ial_authn_context).
          and_return(nil)

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        sp_attributes = %w[email first_name last_name ssn zipcode all_emails]
        service_provider = ServiceProvider.new(attribute_bundle: sp_attributes, ial: 1)
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)

        expect(presenter.requested_attributes).to eq(%i[email all_emails])
      end
    end

    context 'IAL2 and bundle contains invalid attributes' do
      it 'only returns valid attributes named per the OpenId Connect spec' do
        request = FakeSamlRequest.new

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        service_provider = ServiceProvider.new(
          attribute_bundle: %w[
            email first_name last_name dob foo ssn phone verified_at
          ],
        )
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)
        valid_attributes = %i[
          email given_name family_name birthdate social_security_number phone verified_at
        ]

        expect(presenter.requested_attributes).to eq(valid_attributes)
      end
    end

    context 'IAL2 and bundle contains multiple address attributes' do
      it 'consolidates address attributes into one :address attribute' do
        request = FakeSamlRequest.new

        parser = instance_double(SamlRequestParser)
        allow(SamlRequestParser).to receive(:new).with(request).and_return(parser)
        allow(parser).to receive(:requested_attributes).and_return(nil)

        service_provider = ServiceProvider.new(
          attribute_bundle: %w[address1 address2 city state zipcode],
        )
        presenter = SamlRequestPresenter.new(request: request, service_provider: service_provider)

        expect(presenter.requested_attributes).to eq([:address])
      end
    end
  end
end
