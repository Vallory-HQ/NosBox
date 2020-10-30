# NosBox
Vagrant Box para Nosotros

<p align="center">
<a href="https://packagist.org/packages/vallory/nosbox"><img src="https://img.shields.io/badge/license-MIT-success" alt="License"> </a>
</p>

## Specs
| Ubuntu LTS | Mysql Version | Php Version | NosBox Version | Branch
| -----------| -----------   | ----------- | -----------    | -----------
| 20.04      | 5.7           | 7.4         | 1.0            | `master`

## Set up and running

### First Step

Before start cloning the repository you must install VirtualBox as well as Vagrant.

### Installing the NosBox Vagrant Box

Once VirtualBox and Vagrant have been installed, you should add the vallory/nosbox box to your Vagrant installation using the following command in your terminal.

```
$ vagrant box add vallory/nosbox
```

### Installing NosBox

You may install NosBox by cloning the repository onto your host machine. Consider cloning the repository into a NosBox folder within your "home" directory:

```
$ git clone https://github.com/Vallory-HQ/NosBox.git ~/NosBox
```

### Running NosBox

After successfully install NosBox proceed to run the box by typing the next commands on your terminal:

```
$ cd ~/NosBox
$ vagrant up
```

## Ubuntu 20.04
| User    | Password |
| ------- | -------- |
| vagrant | vagrant  |

## Mysql
| User    | Password |
| ------- | -------- |
| root    | secret   |
