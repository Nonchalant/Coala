response=$(curl -X GET -H "Authorization: Bearer ${GITHUB_TOKEN}" "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases/latest")
data=$(echo $response | jq '.assets[] | .data = (.id|tostring) + "," + (.name|tostring) | .data')

echo $response | jq
echo $data | jq

if [ -n "$data" ]; then
  for d in $data
  do
    IFS=,
    set -- $d
    asset_id=$(echo $1 | cut -c 2-)
    curl -sLJH "Accept: application/octet-stream" -o ${2%\"} https://$SSO_GITHUB_TOKEN@api.github.com/repos/$GITHUB_REPOSITORY/releases/assets/${asset_id}
  done
fi

less questions.json | jq
less talks.json | jq

cp questions.json old-questions.json
cp talks.json old-talks.json
