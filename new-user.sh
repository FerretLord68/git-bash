#!/bin/bash

TEMPPASS=Trythis1

echo "what's the username of the new user?"
read USERNAME

echo "what group does the user belong in?"
read USERGROUP

#after getting the information for the new user creation, the user will be createde, with a home dir + givien the correct group.

#creating the user with a home dir
useradd -m $USERNAME

#force the user into the home dir.
usermod -m -d /home/$USERNAME -s /bin/bash $USERNAME

#creating tempery password for new user
passwd $USERNAME

#adding the user to the correct group
adduser $USERNAME $USERGROUP

#force the new user to create a new login on first login
passwd --expire $USERNAME
