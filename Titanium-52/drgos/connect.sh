#!/bin/bash

ssh -oHostKeyAlgorithms=+ssh-rsa -oPubkeyAcceptedKeyTypes=+ssh-rsa -oKexAlgorithms=+diffie-hellman-group1-sha1 -oCiphers=+aes128-cbc haxor@192.168.1.254