#!/bin/bash
################################################################################
################################################################################
# Name:        lpass-zenity.sh
# Description: Displays a zenity window with lpass credentials
# Created:     2020-03-20
# Copyright 2014, Victor Mendonca - http://victormendonca.com
#                                 - https://github.com/victorbrca
# License: Released under the terms of the GNU GPL license v3
################################################################################
################################################################################


#-------------------------------------------------------------------------------
# Sets variables
#-------------------------------------------------------------------------------
lpass_user=""

if ! command -v lpass > /dev/null ; then
  echo "You need the \"lastpass-cli\" package installed"
  echo "See https://github.com/lastpass/lastpass-cli"
  exit 1
elif ! command -v xclip > /dev/null ; then
  echo "You need the \"xclip\" package installed"
  exit 1
fi

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------

_check-status ()
{
  status=$(lpass status || true)
  if [[ "$(echo $status | grep -q 'Not logged' ; echo $?)" -eq "0" ]] ; then
    lpass login "$lpass_user"
  fi
}

_search_prompt ()
{
  search_answer="$(zenity --entry --title=Lastpass --title=Lastpass --text=Search --width=600 --height=300)"
}

_select_account ()
{
  account_id=$(lpass ls --format "%au @ %an - [%ai]" | grep -i "$search_answer" | zenity --title="Lasspass" --list --column="Select an Account" --width=600 --height=300 | awk -F"[" '{print $2}' | tr -d ']')
  if [[ ! $account_id =~ [0-9] ]] ; then
    exit 0
  fi
}

_check_account_selection ()
{
  while [[ ! $account_id =~ [0-9] ]] ; do
    zenity --warning --text="Selection was not made" --width=200 --height=100
    _select_account
  done
}

_copy_password ()
{
  lpass show --password -c $account_id
}

_copy_username ()
{
  lpass show --username -c $account_id
}

_select_username_pass ()
{
  username_passwd_selection=$(zenity  --list --column "Select option" Username Password)
}

_get_creds ()
{
  _search_prompt
  _select_account
  #_check_account_selection
  _select_username_pass
  while [[ $username_passwd_selection != "" ]] ; do
    case $username_passwd_selection in
      Username)
        _copy_username
        sleep 5
        _select_username_pass
        ;;
      Password)
        _copy_password
        exit 0
        ;;
      *)
        exit 0
        ;;
    esac
  done
}

#-------------------------------------------------------------------------------
# Starts script
#-------------------------------------------------------------------------------

_check-status
_get_creds
