module Idv
  module VerifyInfoConcern
    extend ActiveSupport::Concern

    def flow_session
      user_session['idv/doc_auth']
    end
  end
end
