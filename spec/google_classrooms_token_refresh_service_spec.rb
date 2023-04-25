require 'vcr'
require 'debug'
require 'timecop'
require 'google_classrooms_token_refresh_service'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = true
end

RSpec.describe GoogleClassroomsTokenRefreshService do
  let(:access_token) { 'access_token' }
  let(:refresh_token) { 'refresh_token' }
  let(:expires_at) { Time.now }
  subject(:context) do
    described_class.call(access_token: access_token, refresh_token: refresh_token, expires_at: expires_at)
  end

  describe 'when called' do
    context 'with fresh access and refresh tokens' do
      let(:access_token) do
        'ya29.a0Ael9sCOgqHR41UIEYg8TtQE2Ye2-0svfeKSQGHZ90uABF8x-m0dfkhWvloALmEOcoR074Usy6pJmrvrbCA3aSFiWEq877IDvHZy9SUrTNpo36lkRKLB0IORyF_OT9NU5SFXf90N7C6Kp-yIXFSYc3gZ-LbxYaCgYKAVgSARASFQF4udJhxRsrWpWPopSdC5M3ivZDIw0163'
      end
      let(:refresh_token) do
        '1//01FLlZ30Vy2IrCgYIARAAGAESNwF-L9IrfXrRrDTV4zW6qMwD1L8wvXPeWSAcColWT3yM9m-9bhvhEsOinyslwTLG6m4d8R3EhRc'
      end
      let(:expires_at) { Time.at(1_681_686_833) }

      it 'succeeds and returns current token' do
        VCR.use_cassette('fresh_tokens') do |_cassette|
          Timecop.freeze(Time.at(1_681_684_000)) do
            expect(context).to be_a_success
            expect(access_token).to eq(context.access_token)
            expect(refresh_token).to eq(context.refresh_token)
            expect(expires_at).to eq(context.expires_at)
          end
        end
      end
    end

    context 'with stale access token and fresh refresh token' do
      let(:access_token) do
        'ya29.a0Ael9sCOgqHR41UIEYg8TtQE2Ye2-0svfeKSQGHZ90uABF8x-m0dfkhWvloALmEOcoR074Usy6pJmrvrbCA3aSFiWEq877IDvHZy9SUrTNpo36lkRKLB0IORyF_OT9NU5SFXf90N7C6Kp-yIXFSYc3gZ-LbxYaCgYKAVgSARASFQF4udJhxRsrWpWPopSdC5M3ivZDIw0163'
      end
      let(:refresh_token) do
        '1//01FLlZ30Vy2IrCgYIARAAGAESNwF-L9IrfXrRrDTV4zW6qMwD1L8wvXPeWSAcColWT3yM9m-9bhvhEsOinyslwTLG6m4d8R3EhRc'
      end
      let(:expires_at) { Time.at(1_681_686_833) }

      it 'it succeeds and returns fresh access_token' do
        VCR.use_cassette('stale_access_token') do |_cassette|
          Timecop.freeze(Time.at(1_681_686_833)) do
            expect(context).to be_a_success
            expect(access_token).not_to eq(context.access_token)
            expect(refresh_token).to eq(context.refresh_token)
            expect(expires_at).not_to eq(context.expires_at)
          end
        end
      end
    end

    context 'with stale access and refresh tokens' do
      let(:access_token) do
        'ya29.a0Ael9sCMDaaH9ZXlUYevlQGas8oHXK3FsMmrA8igbO1AVYDd75Ev_TbV5ZfY8je7P6707paXrKub_hNjrfAoQovxIoSDLRx2pLdOuN3h8I9TIDn-VShQ5AS41iAl0-ZnUlUbDGDv5IDTvQv7Q8kvsPC4eQqhw65RCOgaCgYKAQUSARISFQF4udJhPDLVA2vlEDhDQefx21gZJw0169'
      end
      let(:refresh_token) do
        '1//01g2GAbS5w31DCgYIARAAGAESNwF-L9Ir57LptYEnkrPiuF2S518ddHYqsukf5JjW-F1UC6td-CLwpjoy_nXojvynowso-PTKFfw'
      end
      let(:expires_at) { Time.at(1_681_000_000) }

      it 'fails' do
        VCR.use_cassette('stale_tokens') do |_cassette|
          Timecop.freeze(Time.at(1_681_436_333)) do
            expect(context).not_to be_a_success
          end
        end
      end
    end

    context 'with fresh tokens but insuficient permissions' do
      let(:access_token) do
        'ya29.a0Ael9sCOD25seBBCcUVymZVN8gjSxyDMhOq7KKOrZAGCNOSZkbNJydzOTEV0ganfAT0_oy8aj3B0bVeMQ3PsfPwDKR_qRm1LvPEWkcVgIzTiA_wdyK7qvza8XebANzAV8RxY2B3L51RIW7cf9p0NjiWK1-0DtaCgYKAbwSARASFQF4udJhHKOY5VoxkFsOvKl63VUHFw0163'
      end
      let(:refresh_token) do
        '1//01OKgxjd-1zVbCgYIARAAGAESNwF-L9IroeNqh2RPGxJf1jX2uMPMBXLCm6CB7pWxmGPO7zpjnUxqhtREizFLPCLrViGMrEKfyow'
      end
      let(:expires_at) { Time.at(1_681_685_309) }

      it 'fails' do
        VCR.use_cassette('fresh_insuficient_tokens') do |_cassette|
          Timecop.freeze(Time.at(1_681_684_709)) do
            expect(context).not_to be_a_success
            expect(access_token).to eq(context.access_token)
            expect(refresh_token).to eq(context.refresh_token)
            expect(expires_at).to eq(context.expires_at)
          end
        end
      end
    end

    context 'with network problems' do
      let(:access_token) do
        'ya29.a0Ael9sCPl0MC7LdOmBg4-Tgducw39ZAoTB2GR950Cgdjo7MaKktM7UPJ2DzHgRFDcV3unxK4_dmZJEQ9kD5zPweGzVh_Zfhu-Jlm3dhcwuZN4_DJGfN5gnqZF-GwhQ6MI8wNIjcLTwPX1IxblZEKNsDDR2hOgaCgYKAegSARASFQF4udJhQbuxe0JhAgWQJ_rUgZykXw0163'
      end
      let(:refresh_token) do
        '1//01xgE95xiltvoCgYIARAAGAESNwF-L9Irif5JmxgxjkWoJCPPoGs-Mqk0fNZLwP3R5xk3B5fqYrhyy48RH7YWveu5qh-73CbpLPw'
      end
      let(:expires_at) { Time.at(1_681_690_652) }

      it 'fails and returns current token' do
        Timecop.freeze(Time.at(1_681_684_000)) do
          expect(context).not_to be_a_success
          expect(access_token).to eq(context.access_token)
          expect(refresh_token).to eq(context.refresh_token)
          expect(expires_at).to eq(context.expires_at)
        end
      end
    end
  end
end
