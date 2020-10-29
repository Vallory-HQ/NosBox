#!/usr/bin/env bash

# Remove any Homestead entries from /etc/hosts and prepare for adding new ones.

sudo sed -i '/#### NOSBOX-SITES-BEGIN/,/#### NOSBOX-SITES-END/d' /etc/hosts

printf "#### NOSBOX-SITES-BEGIN\n#### NOSBOX-SITES-END\n" | sudo tee -a /etc/hosts > /dev/null
