#!/bin/bash

echo "what's the username of the new user?"
read username

echo "what group does the user belong in?"
read usergroup

#after getting the information for the new user creation, the user will be createde, with a home dir + givien the correct group.

#creating the user with a home dir
$(useradd --create-home $username)

#adding the user to the correct group
$(adduser $username $usergroup)

#creating tempery password for new user
$(passwd $username)

#force the new user to create a new login on first login
$(passwd --expire $username)
