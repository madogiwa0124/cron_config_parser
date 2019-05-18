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

You can parse the cron configuration for readability with `CronConfigParser::Parser.call`.

``` ruby
CronConfigParser::Parser.call('00 5 * * * Asia/Tokyo')
=> #<CronConfigParser::CronConfig:0x00007fa4f492e820
 @days=["*"],
 @hours=["5"],
 @minutes=["00"],
 @months=["*"],
 @timezone="Asia/Tokyo",
 @wdays=["*"]>
```

enable check configured properties.

``` ruby
# return false if configured nil or '*'
config = CronConfigParser::Parser.call('00 5 * * * Asia/Tokyo')
config.minutes_difined?
=> true
config.days_difined?
=> false
```

This gem check simple validation when CronConfigParser::CronConfig object initialize.
If the config is invalid, Config::SyntaxError or Config::RequiredError is raised.

``` ruby
# not configured require property.
CronConfigParser::Parser.call('00 5,13 * * ')
=> CronConfigParser::ConfigRequiredError

# configured invalid property.
CronConfigParser::Parser.call('00 5,a * * * Asia/Tokyo')
=> CronConfigParser::ConfigSyntaxError

# this check is Invalidationable.
CronConfigParser::Parser.call('00 5,a * * * Asia/Tokyo', validation: false)
=> #<CronConfigParser::CronConfig:0x00007fcedf09cdf0
 @days=["*"],
 @hours=["5", "a"],
 @minutes=["00"],
 @months=["*"],
 @timezone="Asia/Tokyo",
 @wdays=["*"]>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/cron_config_parser. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the CronConfigParser project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/cron_config_parser/blob/master/CODE_OF_CONDUCT.md).
