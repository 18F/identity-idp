require 'spec_helper'
module SamlIdp
  describe NameIdFormatter do
    subject { described_class.new list }

    describe 'with one item' do
      let(:list) { { email_address: -> { 'foo@example.com' } } }

      it 'has a valid all' do
        expect(subject.all).to eq(['urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'])
      end
    end

    describe 'with options that require different version numbers' do
      let(:list) do
        %i[unspecified email_address x509_subject_name windows_domain_qualified_name
           kerberos entity persistent transient]
      end

      it 'has a valid all' do
        expect(subject.all).to contain_exactly(
          'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified', 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress', 'urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName', 'urn:oasis:names:tc:SAML:1.1:nameid-format:WindowsDomainQualifiedName', 'urn:oasis:names:tc:SAML:2.0:nameid-format:kerberos', 'urn:oasis:names:tc:SAML:2.0:nameid-format:entity', 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent', 'urn:oasis:names:tc:SAML:2.0:nameid-format:transient'
        )
      end
    end

    describe 'with hash describing versions' do
      let(:list) do
        {
          '1.1' => { email_address: -> {} },
          '2.0' => { undefined: -> {} },
        }
      end

      it 'has a valid all' do
        expect(subject.all).to eq(
          [
            'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
            'urn:oasis:names:tc:SAML:2.0:nameid-format:undefined',
          ]
        )
      end
    end

    describe 'with actual list' do
      let(:list) { %i[email_address undefined] }

      it 'has a valid all' do
        expect(subject.all).to eq(
          [
            'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
            'urn:oasis:names:tc:SAML:2.0:nameid-format:undefined',
          ]
        )
      end
    end

    describe '#chosen' do
      let(:list) { { email_address: -> { 'foo@example.com' } } }

      context 'SP requests a nameid-format that is not supported by the IdP' do
        it 'returns the persisent format with id as the getter' do
          sp_format = 'urn:oasis:names:tc:SAML:2.0:nameid-format:foo'
          formatter = NameIdFormatter.new(list, sp_format)
          default_hash = {
            name: 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
            getter: 'id',
          }

          expect(formatter.chosen).to eq default_hash
        end
      end

      context 'SP requests the emailAddress nameid-format that is supported by the IdP' do
        it 'returns the requested format with the getter as defined by the IdP' do
          sp_format = 'urn:oasis:names:tc:SAML:1.1:nameid-format:email_address'
          formatter = NameIdFormatter.new(list, sp_format)

          expect(formatter.chosen[:name]).
            to eq 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
          expect(formatter.chosen[:getter]).to be_a Proc
        end
      end

      context 'SP requests a nameid-format other than email that is supported by the IdP' do
        it 'returns the requested format with the getter as defined by the IdP' do
          sp_format = 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
          list = { persistent: -> { '123-abcd' } }
          formatter = NameIdFormatter.new(list, sp_format)

          expect(formatter.chosen[:name]).
            to eq 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
          expect(formatter.chosen[:getter]).to be_a Proc
        end
      end

      context 'SP requests X509SubjectName nameid-format supported by the IdP' do
        it 'returns the requested format with the getter as defined by the IdP' do
          sp_format = 'urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName'
          list = { x509_subject_name: -> { 'foobar' } }
          formatter = NameIdFormatter.new(list, sp_format)

          expect(formatter.chosen[:name]).
            to eq 'urn:oasis:names:tc:SAML:1.1:nameid-format:X509SubjectName'
          expect(formatter.chosen[:getter]).to be_a Proc
        end
      end

      context 'SP requests WindowsDomainQualifiedName nameid-format supported by the IdP' do
        it 'returns the requested format with the getter as defined by the IdP' do
          sp_format = 'urn:oasis:names:tc:SAML:1.1:nameid-format:WindowsDomainQualifiedName'
          list = { windows_domain_qualified_name: -> { 'foobar' } }
          formatter = NameIdFormatter.new(list, sp_format)

          expect(formatter.chosen[:name]).
            to eq 'urn:oasis:names:tc:SAML:1.1:nameid-format:WindowsDomainQualifiedName'
          expect(formatter.chosen[:getter]).to be_a Proc
        end
      end

      context 'SP requests unspecified nameid-format supported by the IdP' do
        it 'returns the requested format with the getter as defined by the IdP' do
          sp_format = 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'
          list = { unspecified: -> { 'foobar' } }
          formatter = NameIdFormatter.new(list, sp_format)

          expect(formatter.chosen[:name]).
            to eq 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'
          expect(formatter.chosen[:getter]).to be_a Proc
        end
      end
    end
  end
end
