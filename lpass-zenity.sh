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
export LPASS_HOME="${HOME}/.lpass"

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

_check_login_status ()
{
  # Makes sure we are logged in
  status=$(lpass status || true)
  if [[ "$(echo $status | grep -q 'Not logged' ; echo $?)" -eq "0" ]] ; then
    lpass login "$lpass_user"
  fi
}

_initial_screen ()
{
  local ret_code

  # Displays the initial screen where user can search or add a new entry
  while true ; do
    user_input="$(zenity --entry --title=LastPass --text=Search --extra-button \
     "Add Item" --width=600 --height=300)"
    ret_code=$?
    # Cancel
    if [[ $ret_code -eq 1 ]] && [[ "${user_input}x" == "x" ]] ; then
      exit
    # Ok without any input
    elif [[ $ret_code -eq 0 ]] && [[ "${user_input}x" == "x" ]] ; then
      zenity --warning --text="Selection was not made" --width=200 --height=100
      continue
    else
      break
    fi
  done
}


#--- Get credentials -----------------------------------------------------------

# Displays accounts after searching for them
_select_account ()
{
  local ret_code
  
  # Displays accounts based on search result
  while true ; do
    account_id=$(lpass ls --format "%au @ %an - [%ai]" | grep -i "$user_input" \
     | zenity --title="Lasspass" --list --column="Select an Account" --width=600 \
     --height=300)
    ret_code=$?

    # User hit cancel
    if [[ $ret_code -eq 1 ]] ; then
      exit 0

    # User did not select anything
    elif [[ "${account_id}x" == "x" ]] ; then
      zenity --warning --text="Selection was not made" --width=200 --height=100
      continue
      echo "no selection"
    fi

    # Data issue. Account selected did not have an ID
    account_id=$(echo $account_id | awk -F"[" '{print $2}' | tr -d ']')
    if [[ ! $account_id =~ [0-9] ]] ; then
      zenity --warning --text="Account ID: $account_id was not found" --width=200 --height=100
      exit 1
    else
      break
    fi
  done
}

# Copies username to clipboard
_copy_username ()
{
  lpass show --username -c $account_id
}

# Copies password to clipboard
_copy_password ()
{
  lpass show --password -c $account_id
}

# Prompts for username or password selection
_select_username_pass ()
{
  username_passwd_selection=$(zenity  --list --column "Select option" Username \
   Password)
}

# Clears out clipboard
_clear_clipboard ()
{
  echo "" | xclip -selection clipboard
  zenity --notification --window-icon="info" \
   --text="[lpass-zenity] Clipboard has been cleared"
}

# Main function for account search
# Searches account with string; shows username; shows password; clears clipboard 
_get_creds ()
{
  _select_account
  _select_username_pass
  while [[ $username_passwd_selection != "" ]] ; do
    case $username_passwd_selection in
      Username)
        _copy_username
        sleep 2
        _select_username_pass
        ;;
      Password)
        _copy_password
        sleep 5
        _clear_clipboard
        exit 0
        ;;
      *)
        exit 0
        ;;
    esac
  done
}


#--- Add credentials -----------------------------------------------------------

# Gets a list of the folders
folder_list=$(lpass ls --format %ag | sort -u | tr '\n' '|')

# Takes care of generating a new password
_generate_password ()
{
  # Let's see if the user wants a new password
  zenity --question --title "LastPass" \
   --text="Would you like to generate a password?" --width=200 --height=100

  # Creates the password and copies it to the clipboard
  if [[ $? -eq 0 ]] ; then
    passwd_lenght=$(zenity --scale --title="LastPass" \
     --text="Select password lenght" --min-value=1 --max-value=99 --value=24)
    passwd_hash="$(date +%s | sha512sum | base64 | head -c $passwd_lenght)"
    zenity --info --text="Your new password has been copied to your clipboard:\n\n${passwd_hash}" --width=200 --height=100
    printf "$passwd_hash" | xclip -selection clipboard
  fi
}

# Add password prompt
_add_password_prompt ()
{
  local ret_code

  while true ; do
    # Creates the form for the new password
    add_password_values=$(zenity --forms --title "LastPass" --text="Add Password" \
     --add-entry="URL" --add-entry="Name" --add-combo "Folder" --combo-values \
     "$folder_list" --add-entry="Username" --add-password="Password (avoid using '|')" \
     --add-password="Confirm Password" --width=600 --height=300)
    ret_code=$?

    # User hit cancel
    if [[ $ret_code -eq 1 ]] ; then
      exit 0
    fi
    
    # Sets the variables
    url=$(echo $add_password_values | awk -F"|" '{print $1}')
    name=$(echo $add_password_values | awk -F"|" '{print $2}')
    folder=$(echo $add_password_values | awk -F"|" '{print $3}')
    username=$(echo $add_password_values | awk -F"|" '{print $4}')
    passwd=$(echo $add_password_values | awk -F"|" '{print $5}')
    passwd_check=$(echo $add_password_values | awk -F"|" '{print $6}')

    # Checks the values of the variables. They cannot be empyt and passwords must
    # match
    if [[ "${url}x" == "x" ]] || [[ "${name}x" == "x" ]] || \
     [[ "${folder}x" == "x" ]] || [[ "${username}x" == "x" ]] || \
     [[ "${passwd}x" == "x" ]] || [[ "${passwd_check}x" == "x" ]] ; then
      zenity --warning --text="Fields cannot be blank" --width=200 --height=100
      continue
    elif [[ "$passwd" != "$passwd_check" ]] ; then
      zenity --warning --text="Passwords do not match" --width=200 --height=100
      continue
    fi

    # Adds the new cred to lastpass
    echo -e "URL: $url\nUsername: $username\nPassword: $passwd" | lpass add \
     --sync=now --non-interactive "${folder}/${name}"

    # Displays confirmation that entry was added, or not
    # Also clears the clipboard
    if [[ $? -eq 0 ]] ; then
      zenity --info --text="Entry added"
      sleep 5
      _clear_clipboard
      exit 0
    else
      zenity --error --text="Something went wrong"
      exit 1
    fi
  done
}

#-------------------------------------------------------------------------------
# Starts script
#-------------------------------------------------------------------------------

# Let's check that we are logged in
_check_login_status

# Displays initial screen
_initial_screen

# Checks if we are looking up or adding an entry
if [[ "$user_input" == "Add Item" ]] ; then
  _generate_password
  _add_password_prompt
else
  _get_creds
fi
