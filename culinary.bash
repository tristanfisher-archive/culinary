#!/usr/bin/env bash 
#
# Tristan Fisher <tfisher@amplify.com>
#
# Bash script to expediate && bootstrap the chef-solo -> chef-server process
#

#TODO: store the downloads and process in two steps to allow for quicker retries

#Lazy for now - should check -w for all files
if (( $EUID !=0 )); then
  if [[ -t 1 ]]; then 
    sudo "$0" "$@"
  else 
    exit 1
  fi 
  exit 
fi

#Some helper functions:
#Don't indefinitely wait for user input
TIMEOUT=5

function confirm {
  for x in "$@"
  do 
    echo "$x"
  done
  read -t $TIMEOUT -p "Continue? " -n 1 -r 
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo " ... 'n' selected.  This may have negative consequences."
    return 1
  fi 
}

function retry {
  read -p "Try again? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    !!
  fi
}

function yes_or_exit {
  for x in "$@"
  do 
    echo "$x"
  done
  read -p "Continue? " -n 1 -r 
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    exit
  fi 
}


function exists { 
  local __config_file=$1
  if [ -f $__config_file ]; then
    read -p "$__config_file exists, overwrite? " -n 1 -r 
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      exit 1
    fi
  fi
}

#Echo send off a quick warning:
echo "[Warning] Commands automatically confirm after 5 seconds" && sleep 5


#Java is often not in the base apt-get
OS=$(lsb_release -si)
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
VER=$(lsb_release -sr)
#TODO: Case out apt-get and yum updates

#Updated repos greatly improve the chance of this succeeding.
#insert package manager check here
sudo apt-get update

#Start install of client & solo:
confirm 'sudo true && curl -L https://www.opscode.com/chef/install.sh | sudo bash'
sudo true && curl -L https://www.opscode.com/chef/install.sh | sudo bash

sudo mkdir -p /etc/chef/

#Chef-solo configuration file:
exists /etc/chef/solo.rb
cat << 'EOINPUT' > /etc/chef/solo.rb
file_cache_path "/tmp/chef-solo"
cookbook_path "/tmp/chef-solo/cookbooks"
EOINPUT

echo " /etc/chef/solo.rb written"

# Attributes configuration file - provides the values used in configurating chef-server : 
# API only (no web interface).  Add '"webui_enabled": true' if you want the GUI.
exists $HOME/chef.json
#{"chef_server": {"server_url": "http://localhost:4000"},"run_list": [ "recipe[chef-server::rubygems-install]" ]}
cat << 'EOINPUT' > $HOME/chef.json
{"chef_server": {"server_url": "http://localhost:4000"},"run_list": [ "recipe[apt::default]","recipe[build-essential::default]","recipe[chef-server::rubygems-install]" ]}
EOINPUT

echo " $HOME/chef.json written"

#confirm "Most installations do not have gecode pre-installed.  Update repos and do that now?"
#grep out later for version release name.. ubuntu 12.10 = quantal-0.10/
#annoyingly, this does not line up cleanly to release formats of just dists/quantal or anything from lsb_release.

#if [[ $? == 0 ]]; then
#  echo "http://apt.opscode.com quantal-0.10 main" > /etc/apt/sources.list.d/opscode.list
#  echo "deb-src http://apt.opscode.com quantal-0.10 main" > /etc/apt/sources.list.d/opscode.list
#
#  curl http://apt.opscode.com/packages@opscode.com.gpg.key | sudo apt-key add -
#  sudo apt-get update
#  sudo apt-get install libgecode-dev
#fi


echo "sudo chef-solo -c /etc/chef/solo.rb -j ~/chef.json -r http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz"
  
#TODO: check if user already exists to prevent an unnecessary prompt or shell/homedir change
confirm "If you're on linux, you'll like want to do `sudo useradd -s '/bin/sh' -d '/var/lib/chef' -r chef -g chef` before proceeding.  Should I try this now?"
if [[ ! ? == 0 ]]; then
  sudo useradd -s '/bin/sh' -d '/var/lib/chef' -r chef -g chef
fi

sudo chef-solo -c /etc/chef/solo.rb -j ~/chef.json -r http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz
if [[ $? == 0 ]]; then 
    echo "chef-solo successfully installed."
  else
    echo "Track down the above error.  If you are on OSX, you likely will have to install CouchDB, RabbitMQ, Java, gecode manually.  Sorry!" 
fi

#chef-client -v 
#if [[ $? == 0 ]]; then
#  echo "chef-client installed properly."
#  else
#    echo "chef-client did not install properly.  If errors have displayed, track those down before continuing."
#    exit 1
#fi

