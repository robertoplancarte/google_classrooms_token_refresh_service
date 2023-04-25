# frozen_string_literal: true

require 'omniauth-google-oauth2'
require 'oauth2'
require 'interactor'

OAuth2.configure do |config|
  config.silence_extra_tokens_warning = true # default: false
end

# A service object to refresh google classroom Oauth2 tokens
class GoogleClassroomsTokenRefreshService
  include Interactor

  class RecoverableByGoogle < ::StandardError; end
  class Unrecoverable < ::StandardError; end
  class UnreachableGoogle < Unrecoverable; end
  class InsuficientScopes < RecoverableByGoogle; end
  class UnrefreshableToken < RecoverableByGoogle; end
  class ArgumentError < Unrecoverable; end

  before do
    context.fail!(error: ArgumentError) if context.access_token.nil?
    context.fail!(error: ArgumentError) if context.refresh_token.nil?
    context.fail!(error: ArgumentError) if context.expires_at.nil?
  end

  after do
    check_scopes
  end

  def call
    return unless access_token.expired?

    begin
      result = access_token.refresh!
    rescue OAuth2::Error
      context.fail!(error: UnrefreshableToken)
    end

    context.access_token  = result.token
    context.refresh_token = result.refresh_token
    context.expires_at    = result.expires_at
  end

  def check_scopes
    uri    = URI("https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=#{context.access_token}")
    result = Net::HTTP.get(uri)
    scopes = parse_scopes(result)

    expected_scopes = google_with_classrooms_config.last[:scope].split(',').map(&:strip).to_a

    context.fail!(error: InsuficientScopes) if (expected_scopes - scopes).count.positive?
  end

  def parse_scopes(result)
    JSON.parse(result)['scope']&.split(' ')&.map { |x| x.split('/').last }.to_a
  end

  def google_with_classrooms_config
    ['711551580135-89m9riv5pkia0avfkq3nvenhtv7tdek5.apps.googleusercontent.com',
     'ipPPByoWkijdVmTf4ct9nLq-',
     { callback_path: '/users/auth/google_with_classrooms/callback',
       scope: 'classroom.courses.readonly, classroom.announcements,
               classroom.coursework.me,
               classroom.announcements.readonly,
               classroom.courseworkmaterials.readonly,
               classroom.push-notifications,
               classroom.coursework.students',
       name: 'google_with_classrooms' }]
  end

  def omniauth_strategy
    OmniAuth::Strategies::GoogleOauth2.new(:gc, *google_with_classrooms_config)
  end

  def access_token
    @access_token ||= OAuth2::AccessToken.new(omniauth_strategy.client, context.access_token,
                                              refresh_token: context.refresh_token,
                                              expires_at: Time.at(context.expires_at).iso8601)
  end
end
