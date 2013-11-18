# Fake login server for external uaa auth

This project is a proof of concept implmentation of the authentication flow described [here](https://github.com/cloudfoundry/uaa/blob/master/docs/UAA-APIs.rst#trusted-authentication-from-login-server).

## Running locally

### Bosh lite
To use the login-server a local [bosh-lite cloudfoundry install](https://github.com/cloudfoundry/bosh-lite/blob/master/README.md#installation) is required.
After the local cloudfoundry setup make the following changes to your manifest.

### Cloudfoundry manifest changes
- Remove the `login_z1` job.
- Add the following properties:
`login.url http://192.168.176.1:4567`
`uaa.clients.redirect-uri https://uaa.10.244.0.34.xip.io/oauth/token`

Apply the above changes to your cloudfoundry by running `bosh deploy`.

### Running the login server
```
bundle install
ruby fake_login_server.rb
```

### Verifying it all works
In a new shell (so the login server can stay running), login in with the cf cli.
```
cf target api.10.244.0.34.xip.io
cf login --username admin
```
It works when you can login with any password

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

All documentation and source code is copyright of Stark & Wayne LLC.

## Subscription and Support

This documentation & tool is freely available to all people and companies coming to Cloud Foundry and bosh.
