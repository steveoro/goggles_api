# frozen_string_literal: true

# Controller to handle exceptions and return JSON in API-only mode
class ExceptionsController < ActionController::API
  def show
    status = ActionDispatch::ExceptionWrapper.new(request.env, request.env['action_dispatch.exception']).status_code
    message = request.env['action_dispatch.exception'].message

    render json: { error: message }, status:
  end
end
