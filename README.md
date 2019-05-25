# CronConfigParser
You can parse the cron configuration for readability.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cron_config_parser'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cron_config_parser

## Usage

You can parse the cron configuration for readability with `CronConfigParser.call`.

``` ruby
CronConfigParser.call('00 5 * * * Asia/Tokyo')
=> #<CronConfigParser::CronConfig:0x00007fa4f492e820
 @days=["*"],
 @hours=["5"],
 @minutes=["00"],
 @months=["*"],
 @timezone="Asia/Tokyo",
 @wdays=["*"]>
```

You can check configured properties.

``` ruby
# return false if configured nil or '*'
config = CronConfigParser.call('00 5 * * * Asia/Tokyo')
config.minutes_configured?
=> true
config.days_configured?
=> false
```

You can check next execute time.

``` ruby
config = CronConfigParser.call('00 5 * * * Asia/Tokyo')
config.next_execute_at
=> 2019-05-23 05:00:00 +0900

# You can check execute schedule in future by execute_schedule.
config.execute_schedule(execute_count: 5, annotation: 'DailyJob')
=>
[{:annotation=>"DailyJob", :execute_at=>2019-05-23 05:00:00 +0900},
 {:annotation=>"DailyJob", :execute_at=>2019-05-24 05:00:00 +0900},
 {:annotation=>"DailyJob", :execute_at=>2019-05-25 05:00:00 +0900},
 {:annotation=>"DailyJob", :execute_at=>2019-05-26 05:00:00 +0900},
 {:annotation=>"DailyJob", :execute_at=>2019-05-27 05:00:00 +0900}]
```

This gem check simple validation when CronConfigParser::CronConfig object initialize.
If the config is invalid, Config::SyntaxError or Config::RequiredError is raised.

``` ruby
# not configured require property.
CronConfigParser.call('00 5,13 * * ')
=> CronConfigParser::ConfigRequiredError

# configured invalid property.
CronConfigParser.call('00 5,a * * * Asia/Tokyo')
=> CronConfigParser::ConfigSyntaxError

# this check is Invalidationable.
CronConfigParser.call('00 5,a * * * Asia/Tokyo', validation: false)
=> #<CronConfigParser::CronConfig:0x00007fcedf09cdf0
 @days=["*"],
 @hours=["5", "a"],
 @minutes=["00"],
 @months=["*"],
 @timezone="Asia/Tokyo",
 @wdays=["*"]>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Madogiwa0124/cron_config_parser. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CronConfigParser project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Madogiwa0124/cron_config_parser/blob/master/CODE_OF_CONDUCT.md).
