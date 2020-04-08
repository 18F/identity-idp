module Acuant
  class Image < AcuantBase
    def call(body, side)
      assure_id.post_image(body, side.to_i)
    end
  end
end
