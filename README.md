# hiera-storedsafe
A Hiera backend to retrieve secrets from Password StoredSafe (by StoredSafe).

## Dependencies
The Storedsafe gem must be installed on the puppet master.

```
puppetserver gem install storedsafe
```

## Usage
To install the puppet module, clone this repository with the destination `<puppet directory>/modules/hiera_storedsafe` (the lib directory should be directory in the hiera\_storedsafe directory).

Add the hiera\_storedsafe backend to your hiera.yaml config file.
```
---
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: "Storedsafe lookup key"
    lookup_key: hiera_storedsafe::lookup_key

  - name: "Common data"
    path: "common.yaml"
```

To configure the storedsafe connection you can either generate a storedsafe rc file using the [Storedsafe Tokenhandler](https://github.com/storedsafe/tokenhandler) (requires python 2.7) or pass a manual configuration through the hiera.yaml file.

If you're using the tokenhandler, make sure the file is in the home directory of the puppet user and is readable by the puppet user.

For the manual configuration (not recommended), you can pass the token, api key and server directly through the hiera.yaml config file.
```
---
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  - name: "Storedsafe lookup key"
    lookup_key: hiera_storedsfae::lookup_key
    options:
      config:
        server: "my.storedsafe.server"
        token: "my-active-token"
        api_key: "secret"

  - name: "Common data"
    path: "common.yaml"
```
