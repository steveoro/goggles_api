# frozen_string_literal: true

#
# = API audit formatter
#
#   - version:  7.001
#   - author:   Steve A.
#
#   Custom formatter for the API audit, with tags, based on GrapeLogging::Formatters::Default
#
class AuditFormatter
  # Returns the formatted string output for the Audit log
  def call(severity, datetime, _, data)
    "#{format_status(data)}[#{datetime}] #{severity} -- #{format_request(data)}\r\n#{format(data)}"
  end
  #-- -------------------------------------------------------------------------
  #++

  private

  # Basic formatting for the request
  def format_request(data)
    "IP #{data[:ip]}, #{data[:method]} #{data[:path]}, timing: #{format_hash(data[:time])}" if data.is_a?(Hash) && data[:ip].present?
  end

  # Generic formatting output, filtering out specific fields in the data hash
  def format(data)
    case data.class.to_s
    when 'String'
      "    #{data}\r\n----\r\n"

    when 'Exception'
      format_exception(data)

    when 'Hash'
      # Output details only in case of errors:
      "#{format_params(data)}#{format_headers(data)}    Response: #{data[:response]}\r\n----\r\n" if data[:status].to_i >= 400

    else
      "    #{data.inspect}\r\n----\r\n"
    end
  end

  # Output request status
  def format_status(data)
    "#{data[:status]} " if data.is_a?(Hash) && data[:status].present?
  end

  # Specific output for the request params
  def format_params(data)
    return if data[:params].blank?

    "    Params:\r\n#{data[:params].keys.sort.map { |key| "    - #{key}: #{data[:params][key]}" }.join("\r\n")}\r\n"
  end

  # Specific output for the request headers
  def format_headers(data)
    return if data[:headers].blank?

    "    Headers:\r\n#{data[:headers].keys.sort.map { |key| "    - #{key} = #{data[:headers][key]}" }.join("\r\n")}\r\n"
  end

  # Formats the given Hash into "key=value" string pairs, separated by a comma
  def format_hash(hash)
    hash.keys.sort.map { |key| "#{key}=#{hash[key]}" }.join(', ')
  end

  # Formats the backtrace of an exception
  def format_exception(exception)
    backtrace_array = (exception.backtrace || []).map { |line| "\t#{line}" }
    "#{exception.message}\r\n#{backtrace_array.join("\r\n")}\r\n----\r\n"
  end
end
