## R CMD check results

0 errors | 0 warnings | 1 note

* checking for future file timestamps ... NOTE
  unable to verify current time

This NOTE is a transient network/clock check and not related to the package.

## System dependency

This package requires 'curl-impersonate' (<https://github.com/lexiforest/curl-impersonate>)
as a system dependency. GAO.gov uses TLS fingerprint filtering that blocks
standard HTTP clients including base R and 'curl'. Installation instructions
are provided in the README, DESCRIPTION, and a startup message.

## Test environment

* local: Arch Linux, R 4.5.x
* GitHub Actions: ubuntu-latest, R release
