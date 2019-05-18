require "cron_config_parser/version"

module CronConfigParser
  class ConfigSyntaxError < StandardError; end
  class ConfigRequiredError < StandardError; end

  class Parser
    def self.call(cron_config, validation: true)
      new(cron_config, validation: validation).call
    end

    def initialize(cron_config, validation: true)
      @cron_config = cron_config
      @validation = validation
    end

    attr_reader :cron_config, :validation

    def call
      CronConfig.new(cron_config, validation: validation)
    end
  end

  class CronConfig
    NOT_CONFIGURED_MARK = '*'.freeze

    def initialize(cron_config, validation: true)
      cron_config = cron_config.split(' ').map { |item| item.split(',') }
      @minutes, @hours, @days, @months, @wdays, @timezone = cron_config
      # timezone is not multiple values.
      @timezone = @timezone.to_a.first
      validate! if validation
    end

    attr_reader :minutes, :hours, :days, :months, :wdays, :timezone

    # difine properties configured check methods
    [:minutes, :hours, :days, :months, :wdays, :timezone].each do |attr|
      define_method("#{attr}_configured?") do
        value = send(attr).class == Array ? send(attr)[0] : send(attr)
        ![NOT_CONFIGURED_MARK, nil].include?(value)
      end
    end

    private

    def validate!
      check_required_properties!
      check_properties_syntax!
    end

    def check_required_properties!
      if [minutes, hours, days, months, wdays].flatten.include?(nil)
        raise ConfigRequiredError
      end
    end

    def check_properties_syntax!
      raise ConfigSyntaxError if minutes_configured? && !values_in_range?(range: 0..60, values: minutes)
      raise ConfigSyntaxError if hours_configured? && !values_in_range?(range: 0..24, values: hours)
      raise ConfigSyntaxError if days_configured? && !values_in_range?(range: 1..31, values: days)
      raise ConfigSyntaxError if wdays_configured? && !values_in_range?(range: 0..6, values: wdays)
    end

    def values_in_range?(range: , values:)
      values.count == values.count { |value| range.include?(to_i(value)) }
    end

    def to_i(string)
      Integer(string) rescue nil
    end
  end
end
