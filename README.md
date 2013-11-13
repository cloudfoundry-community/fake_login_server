# Fake login server for external uaa auth

This project is a proof of concept implmentation of the authentication flow described [here](https://github.com/cloudfoundry/uaa/blob/master/docs/UAA-APIs.rst#trusted-authentication-from-login-server).

## Running locally

To use the login-server a local [bosh-lite cloudfoundry install](https://github.com/cloudfoundry/bosh-lite/blob/master/README.md#installation) is required.
After the local cloudfoundry setup make the following changes to your manifest.

- Remove the `login_z1` job.
- Add the following properties:
```
login:
  url: http://192.168.176.1:4567
```





