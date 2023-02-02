#!/bin/sh
curl --fail --cookie-jar /tmp/cookies.txt -b /tmp/cookies.txt -s http://127.0.0.1:8080 | grep -q -i 'roundcube webmail'
