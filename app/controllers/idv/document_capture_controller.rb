module Idv
  class DocumentCaptureController < ApplicationController
    #include IdvSession
    include StepIndicatorConcern
    include StepUtilitiesConcern
  end
end
