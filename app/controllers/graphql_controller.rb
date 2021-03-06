# frozen_string_literal: true

class GraphqlController < ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session

  def execute
    render json: result
  rescue => e
    raise e unless Rails.env.development?

    handle_error_in_development e
  end

  private

  def result
    context = { viewer: viewer }
    ProjectBackendSchema.execute(
      params[:query],
      variables: ensure_hash(params[:variables]),
      context: context,
      operation_name: params[:operationName]
    )
  end

  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: 500
  end

  def header
    @header ||= request.headers['Authorization']
    @header ||= header.split(' ').last if @header
  end

  def viewer
    decoded = JsonWebToken.decode(header)
    User.find(decoded[:viewer_id])
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound => _e
    nil
  end
end
