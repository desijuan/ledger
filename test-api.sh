#!/bin/bash

url="localhost:3000/api/entries"

options=(GET POST GET/:id PATCH/:id DELETE/:id)

echo
echo "API test"
echo
while true; do
  select opt in "${options[@]}" "quit"; do
    echo
    case "$opt" in
      GET)
        cmd="curl $url -v"
        echo $cmd
        echo
        eval $cmd --no-progress-meter  | jq
        break;;
      POST)
        read -e -p "data: " data
        echo
        cmd="curl $url -d '$data' -H 'Content-Type: application/json' -v"
        echo $cmd
        echo
        eval $cmd --no-progress-meter | jq
        break;;
      GET/:id)
        read -e -p "id: " id
        echo
        cmd="curl $url/$id -v"
        echo $cmd
        echo
        eval $cmd --no-progress-meter  | jq
        break;;
      PATCH/:id)
        read -e -p "id: " id
        read -e -p "data: " data
        echo
        cmd="curl $url/$id -d '$data' -H 'Content-Type: application/json' -X PATCH -v"
        echo $cmd
        echo
        eval $cmd --no-progress-meter  | jq
        break;;
      DELETE/:id)
        read -e -p "id: " id
        echo
        cmd="curl $url/$id -X DELETE -v"
        echo $cmd
        echo
        eval $cmd --no-progress-meter  | jq
        break;;
      quit)
        echo "Goodbye!"
        break 2;;
      *)
        echo "Invalid option. Try another one."
        continue;;
    esac
  done
  echo
done
echo
