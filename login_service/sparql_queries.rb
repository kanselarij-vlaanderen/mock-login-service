require_relative '/usr/src/app/sinatra_template/utils.rb'

module LoginService
  module SparqlQueries
    include SinatraTemplate::Utils

    def remove_old_sessions(session)
      query = " DELETE WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{MU_SESSION.account}> ?account ;"
      query += "                  <#{MU_CORE.uuid}> ?id ; "
      query += "                  <#{RDF::Vocab::DC.modified}> ?modified ; "
      query += "                  <#{MU_EXT.sessionMembership}> ?membership ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def insert_new_session_for_account(account, session_uri, session_id, membership_uri)
      now = DateTime.now

      query =  " PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>"
      query += " INSERT DATA {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session_uri}> <#{MU_SESSION.account}> <#{account}> ;"
      query += "                      <#{RDF::Vocab::DC.modified}> #{now.sparql_escape} ;"
      query += "                      <#{MU_EXT.sessionMembership}> <#{membership_uri}> ;"
      query += "                      <#{MU_CORE.uuid}> #{session_id.sparql_escape} ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def insert_login_activity(user)
      now = DateTime.now

      # Delete old login activity
      query = %(
      DELETE WHERE {
        GRAPH <#{SYSTEM_USERS_GRAPH}> {
          ?s a <#{MU_EXT.LoginActivity}> ;
            <#{PROV.wasAssociatedWith}> <#{user}> ;
            ?p ?o .
        }
      })
      Mu::AuthSudo.update(query)

      uuid = generate_uuid
      query = %(
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

      INSERT DATA {
        GRAPH <#{SYSTEM_USERS_GRAPH}> {
          <#{LOGIN_ACTIVITY_RESOURCE_BASE}#{uuid}> a <#{MU_EXT.LoginActivity}> ;
            <#{MU_CORE.uuid}> #{uuid.sparql_escape} ;
            <#{PROV.wasAssociatedWith}> <#{user}> ;
            <#{PROV.startedAtTime}> #{now.sparql_escape} .
        }
      })
      Mu::AuthSudo.update(query)
    end

    def select_account_by_session(session)
      query =  " SELECT ?session_id ?account_uri ?account_id ?person_uri ?person_status ?membership_id ?membership_status WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     <#{session}> <#{MU_CORE.uuid}> ?session_id;"
      query += "                  <#{MU_SESSION.account}> ?account_uri ;"
      query += "                  <#{MU_EXT.sessionMembership}> ?membership_uri ."
      query += "   }"
      query += "   GRAPH <#{MOCK_ACCOUNT_GRAPH}> {"
      query += "     ?account_uri a <#{RDF::Vocab::FOAF.OnlineAccount}> ;"
      query += "              <#{MU_CORE.uuid}> ?account_id ."
      query += "     ?membership_uri a <#{ORG.Membership}> ;"
      query += "              <#{ORG.member}> ?person_uri ;"
      query += "              <#{MU_CORE.uuid}> ?membership_id ."
      query += "   }"
      query += "   GRAPH <#{SYSTEM_USERS_GRAPH}> {"
      query += "     ?person_uri <#{ADMS.status}> ?person_status ."
      query += "     ?membership_uri <#{ADMS.status}> ?membership_status ."
      query += "   }"
      query += " } LIMIT 1"
      Mu::AuthSudo.query(query)
    end

    def select_current_session(account)
      query =  " SELECT ?uri WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     ?uri <#{MU_SESSION.account}> <#{account}> ;"
      query += "        <#{MU_CORE.uuid}> ?id . "
      query += "   }"
      query += " } LIMIT 1"
      Mu::AuthSudo.query(query)
    end

    def delete_current_session(account)
      query = " DELETE WHERE {"
      query += "   GRAPH <#{SESSIONS_GRAPH}> {"
      query += "     ?session <#{MU_SESSION.account}> <#{account}> ;"
      query += "              <#{MU_CORE.uuid}> ?id ; "
      query += "              <#{RDF::Vocab::DC.modified}> ?modified ; "
      query += "              <#{MU_EXT.sessionMembership}> ?membership ."
      query += "   }"
      query += " }"
      Mu::AuthSudo.update(query)
    end

    def select_login_data(account_id)
      query = %(
      SELECT ?account ?person ?person_status ?membership ?membership_id ?membership_status
      WHERE {
        GRAPH <#{MOCK_ACCOUNT_GRAPH}> {
          ?account a <#{RDF::Vocab::FOAF.OnlineAccount}> ;
            <#{MU_CORE.uuid}> #{account_id.sparql_escape} .
          ?person <#{RDF::Vocab::FOAF.account}> ?account .
          ?membership <#{ORG.member}> ?person ;
            <#{MU_CORE.uuid}> ?membership_id .
        }
        GRAPH <#{SYSTEM_USERS_GRAPH}> {
          ?person <#{ADMS.status}> ?person_status .
          ?membership <#{ADMS.status}> ?membership_status .
        }
      } LIMIT 1)
      Mu::AuthSudo.query(query)
    end
  end
end
