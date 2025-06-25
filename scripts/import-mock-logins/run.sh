#!/bin/sh
echo ""
echo "Import mock accounts into the triplestore"

curl -X POST http://triplestore:8890/sparql -H "Content-Type: application/sparql-update" --data-binary "@insert_mock_account.sparql"

echo ""
echo "DONE"
