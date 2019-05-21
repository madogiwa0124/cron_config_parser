require "cron_config_parser/version"
require 'active_support/all'

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

    attr_accessor :minutes, :hours, :days, :months, :wdays, :timezone

    # define properties configured check methods
    [:minutes, :hours, :days, :months, :wdays, :timezone].each do |attr|
      define_method("#{attr}_configured?") do
        value = send(attr).class == Array ? send(attr)[0] : send(attr)
        ![NOT_CONFIGURED_MARK, nil].include?(value)
      end
    end

    def next_execute_at(basis_datetime: Time.current)
      ExecuteAtCalculator.new(cron_config: self, basis_datetime: basis_datetime).call
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
      Integer(string) rescue string
    end
  end

  class ExecuteAtCalculator
    WDAYS = %i[sunday monday tuesday wednesday thursday friday saturday].freeze

    def initialize(cron_config:, basis_datetime:)
      @cron_config = cron_config
      @basis_datetime = basis_datetime
      @execute_at = basis_datetime
      prepare_cron_config
    end

    attr_accessor :cron_config, :basis_datetime, :execute_at

    def call
      next_minute
      next_hour
      next_day
      next_wday
      next_month
      execute_at
    end

    private

    def prepare_cron_config
      @cron_config.minutes = parse_config_property(cron_config.minutes, :minutes)
      @cron_config.hours   = parse_config_property(cron_config.hours, :hours)
      @cron_config.days    = parse_config_property(cron_config.days, :days)
      @cron_config.months  = parse_config_property(cron_config.months, :months)
      @cron_config.wdays   = parse_config_property(cron_config.wdays, :wdays)
    end

    def to_i(value)
      Integer(value) rescue value
    end

    def parse_config_property(values, property_sym)
      values.map do |property|
        next to_i(property) unless property.match?(/\/|-/)
        next parse_for_devided_config(property, property_sym) if property.include?('/')
        next parse_for_range_config(property) if property.include?('-')
      end.flatten.uniq.sort
    end

    def parse_for_devided_config(property, property_sym)
      hash = { minutes: 0..60, hours: 0..24, days: 1..31, months: 1..12, wday: 0..6 }
      hash[property_sym].select { |val| (val % (property).split('/')[1].to_i) == 0 }
    end

    def parse_for_range_config(property)
      range_start, range_end = property.split('-').map(&:to_i)
      (range_start..range_end).to_a
    end

    def next_minute
      return @execute_at = execute_at.since(1.minute) unless cron_config.minutes_configured?
      next_minute = cron_config.minutes.select { |config_min| config_min > execute_at.min }.first
      @execute_at = change_to_property_and_move_up(property: next_minute, property_sym: :minutes)
    end

    def next_hour
      return unless cron_config.hours_configured?
      next_hour = cron_config.hours.select { |config_hour| config_hour > execute_at.hour }.first
      @execute_at = change_to_property_and_move_up(property: next_hour, property_sym: :hours)
      # reset minute when execute in freture and not configured minute
      @execute_at = @execute_at.change(min: 0) unless cron_config.minutes_configured?
    end

    def next_day
      return unless cron_config.days_configured?
      next_day = cron_config.days.select { |config_day| config_day > execute_at.day }.first
      @execute_at = change_to_property_and_move_up(property: next_day, property_sym: :days)
      # reset minute when execute in freture and not configured minute
      @execute_at = @execute_at.change(min: 0) unless cron_config.minutes_configured?
    end

    def next_wday
      return unless cron_config.wdays_configured?
      next_wday = cron_config.wdays.select { |config_wday| config_wday > execute_at.wday }.first
      next_wday_sym = next_wday ? WDAYS[next_wday] : WDAYS[cron_config.wdays.first]
      @execute_at = execute_at.next_occurring(next_wday_sym)
      # reset minute when execute in freture and not configured minute
      @execute_at = @execute_at.change(min: 0) unless cron_config.minutes_configured?
    end

    def next_month
      return unless cron_config.months_configured?
      next_month = cron_config.months.select { |config_month| config_month > execute_at.month }.first
      @execute_at = change_to_property_and_move_up(property: next_month, property_sym: :months)
      # reset minute when execute in freture and not configured minute
      @execute_at = @execute_at.change(min: 0) unless cron_config.minutes_configured?
    end

    def change_to_property_and_move_up(property:, property_sym:)
      change_property = convert_hash(property_sym)[:change_property]
      move_up_property = convert_hash(property_sym)[:move_up_property]
      return execute_at.change(change_property => property) if property
      execute_at.since(1.send(move_up_property)).change(
        change_property => cron_config.send(property_sym).first
      )
    end

    def convert_hash(property_sym)
      { minutes: { change_property: :min,   move_up_property: :hour },
        hours:   { change_property: :hour,  move_up_property: :day },
        days:    { change_property: :day,   move_up_property: :month },
        months:  { change_property: :month, move_up_property: :year }, }[property_sym]
    end
  end
end
