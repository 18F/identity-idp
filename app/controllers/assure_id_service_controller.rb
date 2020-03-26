class AssureIdServiceController < ApplicationController
  def subscriptions
    _status, value = assure_id.subscriptions
    render json: value
  end

  def instance
    _status, value = assure_id.create_document
    render json: value
  end

  def document
    assure_id.instance_id = params[:guid]
    _status, value = assure_id.document
    render json: value
  end

  def image
    assure_id.instance_id = params[:guid]
    result = assure_id.post_image(request.body.read, params[:side].to_i)
    render json: result
  end

  def classification
    assure_id.instance_id = params[:guid]
    _status, value = assure_id.classification
    render json: value
  end

  def field_image
    assure_id.instance_id = params[:guid]
    _status, value = assure_id.field_image(params[:key])
    render json: value
  end

  def liveness
    _status, value = Idv::Acuant::Liveness.new.liveness(request.body.read)
    render json: value
  end

  def facematch
    _status, value = Idv::Acuant::Liveness.new.facematch(request.body.read)
    render json: value
  end

  private

  def assure_id
    @assure_id ||= new_assure_id
  end

  def new_assure_id
    klass = Rails.env.test? ? Idv::Acuant::FakeAssureId : Idv::Acuant::AssureId
    klass.new
  end
end
