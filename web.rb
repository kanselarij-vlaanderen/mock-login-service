require 'mu/auth-sudo'
require_relative 'login_service/sparql_queries.rb'

###
# Vocabularies
###

MU_ACCOUNT = RDF::Vocabulary.new(MU.to_uri.to_s + 'account/')
MU_SESSION = RDF::Vocabulary.new(MU.to_uri.to_s + 'session/')
ORG = RDF::Vocabulary.new('http://www.w3.org/ns/org#')
ADMS = RDF::Vocabulary.new('http://www.w3.org/ns/adms#')
PROV = RDF::Vocabulary.new("http://www.w3.org/ns/prov#")

MOCK_ACCOUNT_GRAPH = 'http://mu.semte.ch/graphs/public'
SYSTEM_USERS_GRAPH = "http://mu.semte.ch/graphs/system/users"
SESSIONS_GRAPH = 'http://mu.semte.ch/graphs/sessions'

LOGIN_ACTIVITY_RESOURCE_BASE = "http://themis.vlaanderen.be/id/aanmeldingsactiviteit/"

###
# Constants
###

BLOCKED_STATUS = 'http://themis.vlaanderen.be/id/concept/ffd0d21a-3beb-44c4-b3ff-06fe9561282a'

###
# POST /sessions
#
# Body
# data: {
#   relationships: {
#     account:{
#       data: {
#         id: "account_id",
#         type: "accounts"
#       }
#     }
#   },
#   type: "sessions"
# }
# Returns 201 on successful login
#         400 if session header is missing
#         400 on login failure (incorrect user/password or inactive account)
#         403 user account or membership is blocked
###
post '/sessions/' do
  content_type 'application/vnd.api+json'


  ###
  # Validate headers
  ###
  validate_json_api_content_type(request)

  session_uri = session_id_header(request)
  error('Session header is missing') if session_uri.nil?

  rewrite_url = rewrite_url_header(request)
  error('X-Rewrite-URL header is missing') if rewrite_url.nil?


  ###
  # Validate request
  ###

  data = @json_body['data']

  validate_resource_type('sessions', data)
  error('Id paramater is not allowed', 400) if not data['id'].nil?
  error('exactly one account should be linked') unless data.dig("relationships", "account", "data", "id")

  ###
  # Validate login
  ###

  account_id = data['relationships']['account']['data']['id']
  result = select_login_data(account_id)
  error("account not found.", 400) if result.empty?

  account_uri = result.first[:account].to_s
  person_uri = result.first[:person]
  membership_uri = result.first[:membership].to_s
  membership_id = result.first[:membership_id].to_s

  person_status = result.first[:person_status].to_s
  membership_status = result.first[:membership_status].to_s

  error("This user is blocked.", 403) if person_status == BLOCKED_STATUS
  error("This membership is blocked.", 403) if membership_status == BLOCKED_STATUS

  ###
  # Remove old sessions
  ###
  remove_old_sessions(session_uri)

  ###
  # Insert new session
  ###
  session_id = generate_uuid()
  insert_new_session_for_account(account_uri, session_uri, session_id, membership_uri)

  ###
  # Insert new login activity
  ###
  insert_login_activity(person_uri)

  status 201
  headers['mu-auth-allowed-groups'] = 'CLEAR'
  {
    links: {
      self: rewrite_url.chomp('/') + '/current'
    },
    data: {
      type: 'sessions',
      id: session_id,
      relationships: {
        account: {
          links: {
            related: "/accounts/#{account_id}"
          },
          data: {
            type: "accounts",
            id: account_id
          }
        },
        membership: {
          links: {
            related: "/memberships/#{membership_id}"
          },
          data: {
            type: "memberships",
            id: membership_id
          }
        }
      }
    }
  }.to_json
end


###
# DELETE /sessions/current
#
# Returns 204 on successful logout
#         400 if session header is missing or session header is invalid
###
delete '/sessions/current/?' do
  content_type 'application/vnd.api+json'

  ###
  # Validate session
  ###

  session_uri = session_id_header(request)
  error('Session header is missing') if session_uri.nil?


  ###
  # Get account
  ###

  result = select_account_by_session(session_uri)
  error('Invalid session') if result.empty?
  account_uri = result.first[:account_uri].to_s


  ###
  # Remove session
  ###

  delete_current_session(account_uri)

  status 204
  headers['mu-auth-allowed-groups'] = 'CLEAR'
end


###
# GET /sessions/current
#
# Returns 200 if current session exists
#         400 if session header is missing or session header is invalid
#         403 user account or membership is blocked
###
get '/sessions/current/?' do
  content_type 'application/vnd.api+json'

  ###
  # Validate session
  ###

  session_uri = session_id_header(request)
  error('Session header is missing') if session_uri.nil?


  ###
  # Get account
  ###

  result = select_account_by_session(session_uri)
  error('Invalid session') if result.empty?

  session_id = result.first[:session_id]
  account_id = result.first[:account_id]
  person_uri = result.first[:person_uri]
  membership_id = result.first[:membership_id]

  ###
  # Check blocked status
  ###

  person_status = result.first[:person_status]
  membership_status = result.first[:membership_status]

  error("This user is blocked.", 403) if person_status == BLOCKED_STATUS
  error("This membership is blocked.", 403) if membership_status == BLOCKED_STATUS

  ###
  # Insert new login activity
  ###

  insert_login_activity(person_uri)

  rewrite_url = rewrite_url_header(request)

  status 200
  {
    links: {
      self: rewrite_url.chomp('/')
    },
    data: {
      type: 'sessions',
      id: session_id,
      relationships: {
        account: {
          links: {
            related: "/accounts/#{account_id}"
          },
          data: {
            type: "accounts",
            id: account_id
          }
        },
        membership: {
          links: {
            related: "/memberships/#{membership_id}"
          },
          data: {
            type: "memberships",
            id: membership_id
          }
        }
      }
    }
  }.to_json
end


###
# Helpers
###

helpers LoginService::SparqlQueries
