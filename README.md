# docker-roundcube ![Docker Build](https://github.com/gutmensch/docker-roundcube/actions/workflows/docker-image.yml/badge.svg) [![Docker Pulls](https://img.shields.io/docker/pulls/gutmensch/roundcube.svg)](https://registry.hub.docker.com/u/gutmensch/roundcube/)

Roundcube Docker container built on nginx, php-fpm and s6 overlay configuration.

## Usage

```bash
docker run -d -p 8080:8080 gutmensch/roundcube
```

## Environment variables

To configure Roundcube, you can use `ROUNDCUBE_` environment variables for all regular configuration option (e.g. `ROUNDCUBE_DEFAULT_HOST`, `ROUNDCUBE_SMTP_SERVER`, etc). Additionally, the password plugin file driver adds a `ROUNDCUBE_USER_FILE` variable to set the path to password file.

## License

This repo is published under the [MIT License](http://www.opensource.org/licenses/mit-license.php).
