require "grape_logging"

module GrapeLogging
  module Loggers
    class BinxLogger < GrapeLogging::Loggers::Base
      def forwarded_ip_address
        return @forwarded_ip_address if defined?(@forwarded_ip_address)
        @forwarded_ip_address = request.headers["CF-Connecting-IP"] if request.headers["CF-Connecting-IP"]
        @forwarded_ip_address ||= request.headers["HTTP_X_FORWARDED_FOR"].split(",").last if request.headers["HTTP_X_FORWARDED_FOR"].present?
        @forwarded_ip_address ||= request.headers["REMOTE_ADDR"] || request.headers["ip"]
      end

      def parameters(request, _)
        { remote_ip: forwarded_ip_address, format: "json" }
      end
    end
  end
  # Need to add file parameters to this so it doesn't try (and fail) to make images json
  FILTERED_PARAMS = Rails.application.config.filter_parameters + [:file]
end

module API
  class Base < Grape::API
    use GrapeLogging::Middleware::RequestLogger, instrumentation_key: "grape_key",
                                                 include: [GrapeLogging::Loggers::BinxLogger.new,
                                                           GrapeLogging::Loggers::FilterParameters.new(GrapeLogging::FILTERED_PARAMS)]
    mount API::V3::RootV3
    mount API::V2::RootV2

    def self.respond_to_error(e)
      logger.error e unless Rails.env.test? # Breaks tests...
      eclass = e.class.to_s
      message = "OAuth error: #{e}" if eclass =~ /WineBouncer::Errors/
      opts = { error: message || e.message }
      status_code = status_code_for(e, eclass)
      if Rails.env.production?
        Honeybadger.notify(e) if status_code > 450 # Only notify in production for 500s
      else
        opts[:trace] = e.backtrace[0, 10]
      end
      Rack::Response.new(opts.to_json, status_code, {
        "Content-Type" => "application/json",
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Request-Method" => "*",
      }).finish
    end

    def self.status_code_for(error, eclass)
      if eclass =~ /OAuthUnauthorizedError/
        401
      elsif eclass =~ /OAuthForbiddenError/
        403
      elsif (eclass =~ /RecordNotFound/) || (error.message =~ /unable to find/i)
        404
      else
        (error.respond_to? :status) && error.status || 500
      end
    end
  end
end
