# relago-support
Relago support portal

## Usage
Here's how you can use/start/build projects
### Server
We have many option of running server. Let's see them.
#### `Configuration.nix`
To run server in your config as service, you can import and enable it in your config.
```nix
# add input flake
inputs = {
  relago-support.url = "github:xinux-org/relago-support";
};

# import into your config
imports = [ inputs.relago-support.nixosModules.server ];

# then enable it in service
services.relago-server = {
  enable = true;
  port = 42424; # optional. you can see more in server/module.nix file
};
```

#### Cabal run
You can run it via this command:
```bash
cd server
cabal run -- -c <path-to-config>.toml
```
