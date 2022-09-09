require_relative '../../errorable'

module Scripts
  module InheritedProofing
    module Va
      module UserAttributes
        class TestServer < Idv::InheritedProofing::Va::Service
          include Errorable

          attr_reader :base_uri

          def initialize(auth_code:, private_key_file: nil, base_uri: nil)
            super auth_code

            if private_key_file.present?
              @private_key_file = force_tmp_private_key_file_name(private_key_file)
            end
            @base_uri = base_uri || BASE_URI
          end

          def run
            begin
              # rubocop:disable Layout/LineLength
              puts_message "Retrieving the user's PII from the VA using auth code: '#{auth_code}' at #{request_uri}..."
              puts_message "Retrieved payload containing the user's PII from the VA:\n\tRetrieved user PII: #{user_pii}"
              # rubocop:enable Layout/LineLength

              puts_message "Validating payload containing the user's PII from the VA..."
              if form_response.success?
                puts_success "Retrieved user PII is valid:\n\t#{user_pii}"
              else
                puts_error "Payload returned from the VA is invalid:" \
                  "\n\t#{form.errors.full_messages}"
              end
            rescue => e
              puts_error e.message
            end

            [form, form_response]
          end

          private

          attr_reader :private_key_file

          # Override
          def request_uri
            @request_uri ||= "#{ URI(@base_uri) }/inherited_proofing/user_attributes"
          end

          def user_pii
            @user_pii ||= execute
          end

          def form
            @form ||= Idv::InheritedProofing::Va::Form.new(payload_hash: user_pii)
          end

          def form_response
            @form_response ||= form.submit
          end

          def private_key
            if private_key_file?
              if File.exist?(private_key_file)
                return OpenSSL::PKey::RSA.new(File.read(private_key_file))
              else
                puts_warning "private key file does not exist, using artifacts store: " \
                  "#{private_key_file}"
              end
            end

            AppArtifacts.store.oidc_private_key
          end

          def private_key_file?
            @private_key_file.present?
          end

          # Always ensure we're referencing files in the /tmp/ folder!
          def force_tmp_private_key_file_name(private_key_file)
            "#{Rails.root}/tmp/#{File.basename(private_key_file)}"
          end
        end
      end
    end
  end
end
