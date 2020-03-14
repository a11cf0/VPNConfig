[На русском](README_RU.md)

VPNConfig
=========

A set of sample scripts and configuration files for setting up an advanced VPN server.

Features
--------

* Fully functional virtual LAN , thanks to SoftEther VPN;
* DNS and DHCP services provided by dnsmasq;
* Port forwarding with a dedicated script.;
* IPv6 support;
* All config files and scripts are thoroughly commented.

Requirements
----------

To use this configuration you need the following:
* a Linux server with a static public IP;
* SoftEther VPN;
* dnsmasq;

How to use
----------

To set everything up
1. Configure SoftEther VPN in local bridge mode;
2. Read the comments in the files carefully;
3. Modify netconf and dnsmasq.conf according to your server configuration;
4. Copy the files to appropriate locations, the directory layout should be obvious;
5. Install the provided Softether systemd unit, edit it as needed;
6. Start the services and test.

You can modify anything you want, this is just an example config after all.
It should be easy to adapt this config for Open VPN and possibly other VPN solutions.

License
-------

Copyright (c) 2018-2019 A11CF0
Licensed under WTFPL v2.
