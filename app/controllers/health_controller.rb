class HealthController < ApplicationController
  def show
    db_connected = begin
      ActiveRecord::Base.connection.active?
    rescue StandardError
      false
    end

    status = db_connected ? :ok : :service_unavailable
    render json: {
      status: db_connected ? "ok" : "degraded",
      database: db_connected ? "connected" : "disconnected",
      timestamp: Time.current.iso8601
    }, status: status
  end
end
