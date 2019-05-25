require "cron_config_parser/version"
require 'active_support/all'

module CronConfigParser
  def self.call(cron_config, validation: true)
    Parser.call(cron_config, validation: true)
  end

  private

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

    def initialize(cron_config, validator: CronConfigParser::Varidator, validation: true)
      cron_config = cron_config.split(' ').map { |item| item.split(',') }
      @minutes, @hours, @days, @months, @wdays, @timezone = cron_config
      # timezone is not multiple values.
      @timezone = @timezone.to_a.first
      validator.call!(self) if validation
    end

    attr_accessor :minutes, :hours, :days, :months, :wdays, :timezone

    def next_execute_at(basis_datetime: Time.current)
      calc_next_execute_at(basis_datetime)
    end

    def execute_schedule(basis_datetime: Time.current, execute_count: 1, annotation: '')
      (1..execute_count).map do
        basis_datetime = calc_next_execute_at(basis_datetime)
        { annotation: annotation, execute_at: basis_datetime }
      end
    end

    def calc_next_execute_at(basis_datetime)
      ExecuteAtCalculator.new(cron_config: self, basis_datetime: basis_datetime).call
    end

    # define properties configured check methods
    [:minutes, :hours, :days, :months, :wdays, :timezone].each do |attr|
      define_method("#{attr}_configured?") do
        value = send(attr).class == Array ? send(attr)[0] : send(attr)
        ![NOT_CONFIGURED_MARK, nil].include?(value)
      end
    end
  end

  class Varidator
    class ConfigSyntaxError < StandardError; end
    class ConfigRequiredError < StandardError; end

    def self.call!(cron_config)
      new(cron_config).call!
    end

    def initialize(cron_config)
      @cron_config = cron_config
    end

    def call!
      raise ConfigRequiredError unless configured_required_properties?
      raise ConfigSyntaxError   unless configured_valid_syntax_properties?
    end

    private

    attr_reader :cron_config

    private

    def configured_required_properties?
      ![cron_config.minutes,
        cron_config.hours,
        cron_config.days,
        cron_config.months,
        cron_config.wdays].flatten.include?(nil)
    end

    def configured_valid_syntax_properties?
      return false if cron_config.minutes_configured? && !values_in_range?(:minutes) && !validate_format?(:minutes)
      return false if cron_config.hours_configured?   && !values_in_range?(:hours)   && !validate_format?(:hours)
      return false if cron_config.days_configured?    && !values_in_range?(:days)    && !validate_format?(:days)
      return false if cron_config.wdays_configured?   && !values_in_range?(:wdays)   && !validate_format?(:wdays)
      return false if cron_config.months_configured?  && !values_in_range?(:months)  && !validate_format?(:months)
      true
    end

    def validate_format?(property_sym)
      valid_count = cron_config.send(property_sym).count do |value|
        value.match?(/(\d{1,2}|\*)(\/|-)\d{1,2}/) || value.match?(/\d{1,2}/)
      end
      cron_config.send(property_sym).count == valid_count
    end

    def values_in_range?(property_sym)
      values = cron_config.send(property_sym)
      hash = { minutes: 0..60, hours: 0..24, days: 1..31, months: 1..12, wdays: 0..6 }
      values.count == values.count { |value| hash[property_sym].include?(to_i(value)) }
    end

    def to_i(string)
      Integer(string) rescue string
    end
  end

  class ExecuteAtCalculator
    WDAYS = %i[sunday monday tuesday wednesday thursday friday saturday].freeze

    def initialize(cron_config:, basis_datetime:)
      @cron_config = cron_config.dup
      @basis_datetime = basis_datetime
      @execute_at = basis_datetime
      prepare_cron_config
    end

    attr_accessor :cron_config, :basis_datetime, :execute_at

    def call
      next_minute
      return execute_at if returnable?
      next_hour
      return execute_at if returnable?
      next_day
      return execute_at if returnable?
      next_wday
      return execute_at if returnable?
      next_month
      execute_at
    end

    private

    # check calculated next execution date by below conditions
    # 1.execute_at is future.(remove default add 1 minutes)
    # 2.propaty is not configured or propaty include configured values.
    def returnable?
      execute_at.ago(1.minute) > basis_datetime \
      && (!cron_config.minutes_configured? || cron_config.minutes.include?(execute_at.min)) \
      && (!cron_config.hours_configured? || cron_config.hours.include?(execute_at.hour)) \
      && (!cron_config.days_configured? || cron_config.days.include?(execute_at.day)) \
      && (!cron_config.wdays_configured? || cron_config.wdays.include?(execute_at.wday)) \
      && (!cron_config.months_configured? || cron_config.months.include?(execute_at.month))
    end

    def prepare_cron_config
      @cron_config.minutes = parse_config_property(:minutes)
      @cron_config.hours   = parse_config_property(:hours)
      @cron_config.days    = parse_config_property(:days)
      @cron_config.months  = parse_config_property(:months)
      @cron_config.wdays   = parse_config_property(:wdays)
    end

    def to_i(value)
      Integer(value) rescue value
    end

    def parse_config_property(property_sym)
      result = cron_config.send(property_sym).map do |property|
        next to_i(property) unless property.match?(/\/|-/)
        next parse_for_devided_config(property, property_sym) if property.include?('/')
        next parse_for_range_config(property) if property.include?('-')
      end.flatten.uniq.sort
      result.delete(60)
      result
    end

    def parse_for_devided_config(property, property_sym)
      hash = { minutes: 0..60, hours: 0..24, days: 1..31, months: 1..12, wdays: 0..6 }
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
      check_hash = { hour: next_hour.presence || cron_config.hours[0], min: execute_at.min }
      @execute_at = change_to_property_and_move_up(property: next_hour, property_sym: :hours)
      # reset minute when execute in freture and not configured minute
      reset_execute_at(min: 0)
    end

    def next_day
      return unless cron_config.days_configured?
      next_day = cron_config.days.select { |config_day| config_day >= execute_at.day }.first
      @execute_at = change_to_property_and_move_up(property: next_day, property_sym: :days)
      # reset minute when execute in freture and not configured minute, hour
      reset_execute_at(min: 0, hour: 0)
    end

    def next_wday
      return unless cron_config.wdays_configured?
      next_wday = cron_config.wdays.select { |config_wday| config_wday > execute_at.wday }.first
      next_wday_sym = next_wday ? WDAYS[next_wday] : WDAYS[cron_config.wdays.first]
      @execute_at = execute_at.next_occurring(next_wday_sym)
      # reset minute when execute in freture and not configured minute, hour
      reset_execute_at(min: 0, hour: 0)
    end

    def next_month
      return unless cron_config.months_configured?
      next_month = cron_config.months.select { |config_month| config_month >= execute_at.month }.first
      @execute_at = change_to_property_and_move_up(property: next_month, property_sym: :months)
      # reset minute when execute in freture and not configured minute, hour, day
      reset_execute_at(min: 0, hour: 0, day: 1)
    end

    def reset_execute_at(min: execute_at.min, hour: execute_at.hour, day: execute_at.day)
      @execute_at = @execute_at.change(min: min) unless cron_config.minutes_configured?
      @execute_at = @execute_at.change(hour: hour) unless cron_config.hours_configured?
      @execute_at = @execute_at.change(day: day) unless cron_config.days_configured?
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
