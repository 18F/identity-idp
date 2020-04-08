module Acuant
  class Classification < AcuantBase
    CLASSIFICATION_DATA = {
        'Type': {
        },
    }.freeze

    def call
      # use service when we accept multiple document types and dynamically decide # of sides
      CLASSIFICATION_DATA
    end
  end
end
