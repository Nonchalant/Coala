if [ -e $1 ]; then
  if [ $(cat $1 | jq '. | length') -eq 0 ]; then
    echo "Empty ($1)"
    echo "::set-output name=valid::false"
  else
    echo "::set-output name=valid::true"
  fi
else
  echo "Not Found ($1)"
  echo "::set-output name=valid::false"
fi
