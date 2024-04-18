#!/bin/bash

echo "what's the username of the new user?"
read username

echo "what group does the user belong in?"
read usergroup

echo "what should the password for the user be?"
read password

#after getting the information for the new user creation, the user will be createde, with a home dir + givien the correct group.

#creating the user with a home dir
$(useradd -m $username)

#creating the password for the user
$(passwd $username)
$($password)

#adding the user to the correct group
$(adduser $username $usergroup)

#force the new user to create a new login on first login
$(passwd --expire $username)
