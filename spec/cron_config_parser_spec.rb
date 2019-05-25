RSpec.describe CronConfigParser do
  it 'has a version number' do
    expect(CronConfigParser::VERSION).not_to be nil
  end

  describe '.call' do
    let(:result) { CronConfigParser.call('00 5 * * * Asia/Tokyo') }

    it 'return CronConfig object.' do
      expect(result.class).to eq CronConfigParser::CronConfig
    end
  end

  describe 'Parser' do
    describe '.call' do
      let(:result) { CronConfigParser::Parser.call('00 5 * * * Asia/Tokyo') }

      it 'return CronConfig object.' do
        expect(result.class).to eq CronConfigParser::CronConfig
      end
    end
  end

  describe 'CronConfig' do
    describe '.new' do
      context 'success' do
        let(:object) { CronConfigParser::CronConfig.new('00 5,13 * * * Asia/Tokyo') }

        it 'return initialized object.' do
          expect(object.class).to eq CronConfigParser::CronConfig
        end

        it 'The minutes of object is parsed.' do
          expect(object.minutes).to eq ['00']
        end

        it 'The hours of object is parsed.' do
          expect(object.hours).to eq ['5', '13']
        end

        it 'The days of object is parsed.' do
          expect(object.days).to eq ['*']
        end

        it 'The months of object is parsed.' do
          expect(object.months).to eq ['*']
        end

        it 'The wdays of object is parsed.' do
          expect(object.wdays).to eq ['*']
        end

        it 'The timezone of object is parsed.' do
          expect(object.timezone).to eq 'Asia/Tokyo'
        end
      end

      context 'Required property have not been set' do
        let(:config) { '00 5,13 * * ' }

        it 'raise ConfigRequiredError' do
          expect {
            CronConfigParser::CronConfig.new(config)
          }.to raise_error CronConfigParser::Varidator::ConfigRequiredError
        end
      end

      context 'invalid property format' do
        let(:config) { '00 5,a * * * Asia/Tokyo' }

        it 'raise ConfigSyntaxError' do
          expect {
            CronConfigParser::CronConfig.new(config)
          }.to raise_error CronConfigParser::Varidator::ConfigSyntaxError
        end
      end

      context 'Invalidation check' do
        let(:config) { '00 5,a * * * Asia/Tokyo' }

        it 'return initialized object.' do
          object = CronConfigParser::CronConfig.new(config, validation: false)
          expect(object.class).to eq CronConfigParser::CronConfig
        end
      end
    end

    describe '#execute_schedule' do
      let(:now) { Time.current }

      describe 'argument execute_count' do
        let(:basis_datetime) { Time.new(now.year, 5, 27, 0, 0) }
        let(:object) { CronConfigParser::CronConfig.new('*/10 * * * * Asia/Tokyo') }

        context 'not configured argument' do
          let(:result) { object.execute_schedule(basis_datetime: basis_datetime) }

          it 'return first next execute at' do
            expect(result).to eq [{ execute_at: basis_datetime.change(min: 10), annotation: '' }]
          end
        end

        context 'execute_count >= 2' do
          let(:result) { object.execute_schedule(basis_datetime: basis_datetime, execute_count: 3) }
          it 'return first to third next execute at' do
            expect(result).to eq [
              { execute_at: basis_datetime.change(min: 10), annotation: '' },
              { execute_at: basis_datetime.change(min: 20), annotation: '' },
              { execute_at: basis_datetime.change(min: 30), annotation: ''}
            ]
          end
        end
      end

      describe 'argument annotation' do
        let(:basis_datetime) { Time.new(now.year, 5, 27, 0, 0) }
        let(:object) { CronConfigParser::CronConfig.new('*/10 * * * * Asia/Tokyo') }

        context 'not configured argument' do
          let(:result) { object.execute_schedule(basis_datetime: basis_datetime) }
          it 'return first next execute at' do
            expect(result).to eq [ {execute_at: basis_datetime.change(min: 10), annotation: ''} ]
          end
        end

        context 'configured annotation' do
          let(:result) { object.execute_schedule(basis_datetime: basis_datetime, annotation: 'Hoge') }
          it 'return first next execute at with annotation' do
            expect(result).to eq [ {execute_at: basis_datetime.change(min: 10), annotation: 'Hoge' } ]
          end
        end
      end
    end

    describe '#next_execute_at' do
      let(:now) { Time.current }

      describe 'edge setting' do
        let(:result) { object.next_execute_at(basis_datetime: basis_datetime) }

        context 'configured: 00 12 1,2 1,2,3 *' do
          let(:object) { CronConfigParser::CronConfig.new('00 12 1,2 1,2,3 *') }

          context 'first' do
            let(:basis_datetime) { "2020-01-01 12:00".in_time_zone }
            it { expect(result).to eq "2020-01-02 12:00".in_time_zone }
          end

          context 'second' do
            let(:basis_datetime) { "2020-01-02 12:00".in_time_zone }
            it { expect(result).to eq "2020-02-01 12:00".in_time_zone }
          end
        end

        context 'configured: 00,30 0-6 * * *' do
          let(:object) { CronConfigParser::CronConfig.new('00,30 0-6 * * *') }

          context 'first' do
            let(:basis_datetime) { "2019-05-26 01:00".in_time_zone }
            it { expect(result).to eq "2019-05-26 01:30".in_time_zone }
          end

          context 'second' do
            let(:basis_datetime) { "2019-05-26 01:30".in_time_zone }
            it { expect(result).to eq "2019-05-26 02:00".in_time_zone }
          end
        end
      end

      describe 'common setting' do
        let(:result) { object.next_execute_at(basis_datetime: basis_datetime) }

        context 'every 10 minutes: */10 * * * * Asia/Tokyo' do
          let(:object) { CronConfigParser::CronConfig.new('*/10 * * * * Asia/Tokyo') }

          context 'first' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 0) }
            it { expect(result).to eq basis_datetime.change(min: 10) }
          end

          context 'second' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 10) }
            it { expect(result).to eq basis_datetime.change(min: 20) }
          end
        end

        context 'every hour: 00 * * * * Asia/Tokyo' do
          let(:object) { CronConfigParser::CronConfig.new('00 * * * * Asia/Tokyo') }

          context 'first' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, 0, 0) }
            it { expect(result).to eq basis_datetime.change(hour: 1, min: 0) }
          end

          context 'second' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, 0, 59) }
            it { expect(result).to eq basis_datetime.change(hour: 1, min: 0) }
          end
        end

        context 'every monday: * * * * 1 Asia/Tokyo' do
          let(:object) { CronConfigParser::CronConfig.new('* * * * 1 Asia/Tokyo') }

          context 'first' do
            let(:basis_datetime) { Time.new(now.year, 5, 20, 23, 59) }
            it { expect(result).to eq basis_datetime.change(day: 27, hour: 0, min: 0) }
          end

          context 'second' do
            let(:basis_datetime) { Time.new(now.year, 5, 27, 23, 59) }
            it { expect(result).to eq basis_datetime.change(month: 6, day: 3, hour: 0, min: 0) }
          end
        end

        context 'every beginning of the month: 00 00 1 * * Asia/Tokyo' do
          let(:object) { CronConfigParser::CronConfig.new('00 00 1 * * Asia/Tokyo') }

          context 'first' do
            let(:basis_datetime) { Time.new(now.year, 5, 27, 23, 59) }
            it { expect(result).to eq basis_datetime.change(month: 6, day: 1, hour: 0, min: 0) }
          end

          context 'second' do
            let(:basis_datetime) { Time.new(now.year, 6, 1, 0, 0) }
            it { expect(result).to eq basis_datetime.change(month: 7, day: 1, hour: 0, min: 0) }
          end
        end
      end

      describe 'minutes' do
        let(:result) { object.next_execute_at(basis_datetime: basis_datetime) }

        context 'not configured' do
          let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, now.min) }
          let(:object) { CronConfigParser::CronConfig.new('* * * * * Asia/Tokyo') }

          it 'return 1 minutes since time' do
            expect(result).to eq basis_datetime.since(1.minute)
          end
        end

        context 'single minute' do
          let(:object) { CronConfigParser::CronConfig.new('30 * * * * Asia/Tokyo') }

          context 'no move up' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 20) }

            it 'return configured minute time ' do
              expect(result).to eq basis_datetime.change(min: 30)
            end
          end

          context 'move up' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 30) }

            it 'return since 1hour and configured minute time' do
              expect(result).to eq basis_datetime.since(1.hour).change(min: 30)
            end
          end

          context 'multi configured' do
            let(:object) { CronConfigParser::CronConfig.new('15,30,45 * * * * Asia/Tokyo') }

            context 'basis_datetime minute before first configured minute' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 0) }

              it 'return since 1hour and configured minute time' do
                expect(result).to eq basis_datetime.change(min: 15)
              end
            end

            context 'basis_datetime minute after first configured minute' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 20) }

              it 'return since 1hour and configured minute time' do
                expect(result).to eq basis_datetime.change(min: 30)
              end
            end
          end

          context 'division configured' do
            let(:object) { CronConfigParser::CronConfig.new('*/5 * * * * Asia/Tokyo') }

            context 'basis_datetime minute before first configured minute' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 0) }

              it 'return since first configured minute time' do
                expect(result).to eq basis_datetime.change(min: 5)
              end
            end

            context 'basis_datetime minute before second configured minute' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 5) }

              it 'return since first configured minute time' do
                expect(result).to eq basis_datetime.change(min: 10)
              end
            end
          end

          context 'range configured' do
            let(:object) { CronConfigParser::CronConfig.new('1-5 * * * * Asia/Tokyo') }

            context 'basis_datetime minute before first configured minute' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 0) }

              it 'return since first configured minute time' do
                expect(result).to eq basis_datetime.change(min: 1)
              end
            end

            context 'basis_datetime minute before second configured minute' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, now.hour, 1) }

              it 'return since first configured minute time' do
                expect(result).to eq basis_datetime.change(min: 2)
              end
            end
          end
        end
      end

      describe 'hours' do
        let(:result) { object.next_execute_at(basis_datetime: basis_datetime) }

        context 'single hour' do
          let(:object) { CronConfigParser::CronConfig.new('* 5 * * * Asia/Tokyo') }

          context 'no move up' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, 4, now.min) }

            it 'return configured hour time' do
              expect(result).to eq basis_datetime.change(hour: 5, min: 0)
            end
          end

          context 'move up' do
            let(:basis_datetime) { Time.new(now.year, now.month, now.day, 5, now.min) }

            it 'return since day and configured hour time' do
              expect(result).to eq basis_datetime.since(1.day).change(hour: 5, min: 0)
            end
          end

          context 'multi configured' do
            let(:object) { CronConfigParser::CronConfig.new('* 5,12 * * * Asia/Tokyo') }

            context 'basis_datetime hour before first configured hour' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, 4, now.min) }

              it 'return since 1hour and configured minute time' do
                expect(result).to eq basis_datetime.change(hour: 5, min: 0)
              end
            end

            context 'basis_datetime hour after first configured hour' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, 5, now.min) }

              it 'return since 1hour and configured minute time' do
                expect(result).to eq basis_datetime.change(hour: 12, min: 0)
              end
            end
          end

          context 'division configured' do
            let(:object) { CronConfigParser::CronConfig.new('00 */3 * * * Asia/Tokyo') }

            context 'basis_datetime minute before first configured hour' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, 0, 0) }

              it 'return since first configured minute time' do
                expect(result).to eq basis_datetime.change(hour: 3)
              end
            end

            context 'basis_datetime minute before second configured hour' do
              let(:basis_datetime) { Time.new(now.year, now.month, now.day, 3, 0) }

              it 'return since second configured hour time' do
                expect(result).to eq basis_datetime.change(hour: 6)
              end
            end
          end
        end
      end

      describe 'days' do
        let(:result) { object.next_execute_at(basis_datetime: basis_datetime) }

        context 'single day' do
          let(:object) { CronConfigParser::CronConfig.new('* * 15 * * Asia/Tokyo') }

          context 'no move up' do
            let(:basis_datetime) { Time.new(now.year, now.month, 14, now.hour, now.min) }

            it 'return configured day time' do
              expect(result).to eq basis_datetime.change(day: 15, hour: 0, min: 0)
            end
          end

          context 'move up' do
            let(:basis_datetime) { Time.new(now.year, now.month, 15, 23, 59) }

            it 'return since month and configured day time' do
              expect(result).to eq basis_datetime.since(1.month).change(day: 15, hour:0, min: 0)
            end
          end

          context 'multi configured' do
            let(:object) { CronConfigParser::CronConfig.new('* * 15,20 * * Asia/Tokyo') }

            context 'basis_datetime day before first configured day' do
              let(:basis_datetime) { Time.new(now.year, now.month, 14, now.hour, now.min) }

              it 'return fitst configured day time' do
                expect(result).to eq basis_datetime.change(day: 15, hour: 0, min: 0)
              end
            end

            context 'basis_datetime day after first configured day' do
              let(:basis_datetime) { Time.new(now.year, now.month, 15, 23, 59) }

              it 'return since 1hour and configured minute time' do
                expect(result).to eq basis_datetime.change(day: 20, hour: 0, min: 0)
              end
            end
          end
        end
      end

      describe 'wdays' do
        let(:result) { object.next_execute_at(basis_datetime: basis_datetime) }

        context 'single wday' do
          let(:object) { CronConfigParser::CronConfig.new('* * * * 6 Asia/Tokyo') }

          context 'no move up' do
            let(:basis_datetime) { Time.new(2019, 5, 20, now.hour, now.min) }

            it 'return configured day time' do
              expect(result).to eq basis_datetime.change(day: 25, hour: 0, min: 0)
            end
          end
        end

        context 'multi configured' do
          let(:object) { CronConfigParser::CronConfig.new('* * * * 1,6 Asia/Tokyo') }

          context 'basis_datetime wday before first configured wday' do
            let(:basis_datetime) { Time.new(2019, 5, 19, now.hour, now.min) }

            it 'return fitst configured wday time' do
              expect(result).to eq basis_datetime.change(day: 20, hour: 0, min: 0)
            end
          end

          context 'basis_datetime wday after first configured wday' do
            let(:basis_datetime) { Time.new(2019, 5, 20, now.hour, now.min) }

            it 'return second configured minute time' do
              expect(result).to eq basis_datetime.change(day: 25, hour:0, min: 0)
            end
          end
        end
      end

      describe 'month' do
        let(:result) { object.next_execute_at(basis_datetime: basis_datetime) }

        context 'single month' do
          let(:object) { CronConfigParser::CronConfig.new('* * * 9 * Asia/Tokyo') }

          context 'no move up' do
            let(:basis_datetime) { Time.new(now.year, 8, now.day, now.hour, now.min) }

            it 'return configured month time' do
              expect(result).to eq basis_datetime.change(month: 9, day: 1, hour: 0, min: 0)
            end
          end

          context 'move up' do
            let(:basis_datetime) { Time.new(now.year, 9, 30, 23, 59) }

            it 'return since year and configured month time' do
              expect(result).to eq basis_datetime.since(1.year).change(month: 9, day: 1, hour: 0, min: 0)
            end
          end

          context 'multi configured' do
            let(:object) { CronConfigParser::CronConfig.new('* * * 9,12 * Asia/Tokyo') }

            context 'basis_datetime month before first configured month' do
              let(:basis_datetime) { Time.new(now.year, 8, now.day, now.hour, now.min) }

              it 'return first configured month time' do
                expect(result).to eq basis_datetime.change(month: 9, day: 1, hour: 0, min: 0)
              end
            end

            context 'basis_datetime month after first configured month' do
              let(:basis_datetime) { Time.new(now.year, 9, 30, 23, 59) }

              it 'return since year and configured month time' do
                expect(result).to eq basis_datetime.change(month: 12, day: 1, hour: 0, min: 0)
              end
            end
          end
        end
      end
    end

    describe '#minutes_configured?' do
      context 'configured' do
        let(:object) { CronConfigParser::CronConfig.new('00 5 * * * Asia/Tokyo') }
        it { expect(object).to be_minutes_configured }
      end

      context '* is not configured' do
        let(:object) { CronConfigParser::CronConfig.new('* 5 * * * Asia/Tokyo') }
        it { expect(object).to_not be_minutes_configured }
      end
    end

    describe '#timezone_configured?' do
      context 'configured' do
        let(:object) { CronConfigParser::CronConfig.new('00 5 * * * Asia/Tokyo') }
        it { expect(object).to be_timezone_configured }
      end

      context 'nil is not configured' do
        let(:object) { CronConfigParser::CronConfig.new('00 5 * * *') }
        it { expect(object).to_not be_timezone_configured }
      end
    end
  end
end
