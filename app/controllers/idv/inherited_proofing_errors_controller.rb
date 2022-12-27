module Idv
  class InheritedProofingErrorsController < ApplicationController
    include IdvSession
    include InheritedProofingConcern
    include InheritedProofingPresenterConcern

    def warning
    end

    def failure
    end
  end
end
