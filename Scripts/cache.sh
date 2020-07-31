if [ -e questions.json ]; then
  diff1=$(diff questions.json old-questions.json 2>&1)
fi

if [ -e talks.json ]; then
  diff2=$(diff talks.json old-talks.json 2>&1)
fi

if [ -z "$diff1" -a -z "$diff2" ]; then
  echo "No Diff"
  exit 0;
fi

release_id=$(curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -d "{ \"tag_name\": \"$GITHUB_RUN_ID\" }" \
  https://api.github.com/repos/$GITHUB_REPOSITORY/releases | jq '.id')

echo $release_id

if [ -e questions.json ]; then
  curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -d @questions.json \
    https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/$release_id/assets\?name\=questions.json
fi

if [ -e talks.json ]; then
  curl -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -d @talks.json \
    https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/$release_id/assets\?name\=talks.json
fi

less questions.json | jq
less talks.json | jq
