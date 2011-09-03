#!/bin/sh

# Example script for starting apn_sender
# put in your rails root directory

# start daemon
#   Development Certificate in: /home/user/railsapp/config/certs/<application.bundle.id>/apn_development.pem  
#   Production Certificate in: /home/user/railsapp/config/certs/<application.bundle.id>/apn_production.pem  
script/apn_sender --environment=development --verbose -a application.bundle.id --cert-path=/home/user/railsapp/config/certs start

# run in foreground
#script/apn_sender --environment=development --verbose -a application.bundle.id --cert-path=/home/user/railsapp/config/certs start

