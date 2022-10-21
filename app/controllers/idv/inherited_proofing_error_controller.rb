module Idv
  class InheritedProofingErrorController < ApplicationController
    include IdvSession

    def show
      render 'idv/inherited_proofing/error/failure'
    end
  end
end
