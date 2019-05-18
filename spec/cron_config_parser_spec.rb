RSpec.describe CronConfigParser do
  it 'has a version number' do
    expect(CronConfigParser::VERSION).not_to be nil
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
          }.to raise_error CronConfigParser::ConfigRequiredError
        end
      end

      context 'invalid property format' do
        let(:config) { '00 5,a * * * Asia/Tokyo' }

        it 'raise ConfigSyntaxError' do
          expect {
            CronConfigParser::CronConfig.new(config)
          }.to raise_error CronConfigParser::ConfigSyntaxError
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
