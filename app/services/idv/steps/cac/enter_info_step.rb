module Idv
  module Steps
    module Cac
      class EnterInfoStep < DocAuthBaseStep
        CAC_FIRST_NAME = 'John'.freeze
        CAC_LAST_NAME = 'Doe'.freeze
        PII_FIELDS = %i[first_name last_name address1 address2 city state zipcode dob ssn].freeze

        def call
          store_info_in_session
        end

        private

        def store_info_in_session
          data = params[:doc_auth]
          flow_session[:pii_from_doc] = {}
          PII_FIELDS.each do |key|
            flow_session[:pii_from_doc][key] = data[key]
          end
        end

        def form_submit
          doc_auth_params = params[:doc_auth]
          doc_auth_params[:first_name] = CAC_FIRST_NAME
          doc_auth_params[:last_name] = CAC_LAST_NAME
          Idv::CacForm.new(user: current_user, previous_params: {}).submit(doc_auth_params)
        end
      end
    end
  end
end
