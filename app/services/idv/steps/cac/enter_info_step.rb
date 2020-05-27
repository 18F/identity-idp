module Idv
  module Steps
    module Cac
      class EnterInfoStep < DocAuthBaseStep
        PII_FIELDS = %i[first_name last_name address1 address2 city state zipcode dob ssn].freeze

        def call
          store_info_in_session
        end

        private

        def store_info_in_session
          data = params[:doc_auth]
          flow_session[:pii_from_doc] = { 'uuid' => current_user.uuid }
          PII_FIELDS.each do |key|
            flow_session[:pii_from_doc][key] = data[key]
          end
        end

        def form_submit
          doc_auth_params = params[:doc_auth]
          doc_auth_params[:first_name] = flow_session['first_name']
          doc_auth_params[:last_name] = flow_session['last_name']
          Idv::CacForm.new(user: current_user, previous_params: {}).submit(doc_auth_params)
        end
      end
    end
  end
end
