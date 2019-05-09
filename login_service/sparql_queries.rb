require_relative '/usr/src/app/sinatra_template/utils.rb'
require_relative '/config/config.rb'

module LoginService
  module SparqlQueries
    include SinatraTemplate::Utils
    include LoginConfig
    def remove_old_sessions(session)
      query = " DELETE WHERE {"
      query += "   GRAPH <http://mu.semte.ch/graphs/sessions> {"
      query += "     <#{session}> <#{MU_SESSION.account}> ?account ;"
      query += "                  <#{MU_CORE.uuid}> ?id ; "
      query += "                  <#{RDF::Vocab::DC.modified}> ?modified ; "
      query += "                  <#{MU_EXT.sessionRole}> ?role ;"
      query += "                  <#{MU_EXT.sessionGroup}> ?group ."
      query += "   }"
      query += " }"
      update(query)
    end

    def insert_new_session_for_account(account, session_uri, session_id, group_uri, group_id, roles)
      now = DateTime.now

      query =  " PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>"
      query += " INSERT DATA {"
      query += "   GRAPH <http://mu.semte.ch/graphs/sessions> {"
      query += "     <#{session_uri}> <#{MU_SESSION.account}> <#{account}> ;"
      query += "                      <#{RDF::Vocab::DC.modified}> #{now.sparql_escape} ;"
      query += "                      <#{MU_EXT.sessionGroup}> <#{group_uri}> ;"
      query += "                      <#{MU_CORE.uuid}> #{session_id.sparql_escape} ."
      roles.each do |role|
        query += "   <#{session_uri}> <#{MU_EXT.sessionRole}> #{role.sparql_escape} ."
      end
      query += "   }"
      query += " }"
      update(query)
    end

    def select_account_by_session(session)
      query =  " SELECT ?session_uuid ?group_uuid ?account_uuid ?account (GROUP_CONCAT(?role; SEPARATOR = ',') as ?roles) WHERE {"
      query += "   GRAPH <http://mu.semte.ch/graphs/sessions> {"
      query += "     <#{session}> <#{MU_CORE.uuid}> ?session_uuid;"
      query += "                  <#{MU_SESSION.account}> ?account ;"
      query += "                  <#{MU_EXT.sessionRole}> ?role ;"
      query += "                  <#{MU_EXT.sessionGroup}> ?group ."
      query += "   }"
      query += "   #{group_filter}"
      query += "   GRAPH ?g {"
      query += "     ?account a <#{RDF::Vocab::FOAF.OnlineAccount}> ;"
      query += "              <#{MU_CORE.uuid}> ?account_uuid ."
      query += "   }"
      query += "   "
      query += " } GROUP BY ?session_uuid ?group_uuid ?account_uuid ?account"
      query(query)
    end

    def select_current_session(account)
      query =  " SELECT ?uri WHERE {"
      query += "   GRAPH <http://mu.semte.ch/graphs/sessions> {"
      query += "     ?uri <#{MU_SESSION.account}> <#{account}> ;"
      query += "        <#{MU_CORE.uuid}> ?id . "
      query += "   }"
      query += " }"
      query(query)
    end

    def delete_current_session(account)
      query = " DELETE WHERE {"
      query += "   GRAPH <http://mu.semte.ch/graphs/sessions> {"
      query += "     ?session <#{MU_SESSION.account}> <#{account}> ;"
      query += "              <#{MU_CORE.uuid}> ?id ; "
      query += "              <#{RDF::Vocab::DC.modified}> ?modified ; "
      query += "              <#{MU_EXT.sessionRole}> ?role ;"
      query += "              <#{MU_EXT.sessionGroup}> ?group ."
      query += "   }"
      query += " }"
      update(query)
    end

    def select_account(id)
      query =  " SELECT ?uri WHERE {"
      query += "   #{group_filter}"
      query += "   GRAPH ?g {"
      query += "     ?uri a <#{RDF::Vocab::FOAF.OnlineAccount}> ;"
      query += "          <#{MU_CORE.uuid}> \"#{id}\" ."
      query += "     ?person a <#{RDF::Vocab::FOAF.Person}> ;"
      query += "             <#{RDF::Vocab::FOAF.account}> ?uri ;"
      query += "             ^<#{RDF::Vocab::FOAF.member}> ?group ."
      query += "   }"
      query += "   BIND(IRI(CONCAT(\"http://mu.semte.ch/graphs/organizations/\", ?group_uuid)) as ?g)"
      query += " }"
      query(query)
    end

    def select_group(group_id)
      restricted_filter = group_filter
      restricted_filter.gsub("?group_uuid", "\"#{group_id}\"")
      query =  " SELECT ?group WHERE {"
      query += "    #{group_filter}"
      query += " }"
      query(query)
    end


    def select_roles(account_id)
      query =  " SELECT ?role WHERE {"
      query += "   #{group_filter}"
      query += "   GRAPH ?g {"
      query += "     ?uri a <#{RDF::Vocab::FOAF.OnlineAccount}> ;"
      query += "            <#{MU_CORE.uuid}> \"#{account_id}\" ."
      query += "     ?person a <#{RDF::Vocab::FOAF.Person}> ;"
      query += "             <#{RDF::Vocab::FOAF.account}> ?uri ;"
      query += "             ^<#{RDF::Vocab::FOAF.member}> ?group ."
      query += "     ?group <#{RDF::Vocab::FOAF.name}> ?role ."
      query += "   }"
      query += "   BIND(IRI(CONCAT(\"http://mu.semte.ch/graphs/organizations/\", ?group_uuid)) as ?g)"
      query += " }"
      query(query)
    end
  end
end
