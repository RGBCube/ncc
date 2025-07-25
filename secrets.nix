let
  inherit (import ./keys.nix) admins all best disk nine pala;
in {
  # best
  "hosts/best/id.age".publicKeys            = [ best ] ++ admins;
  "hosts/best/password.age".publicKeys  = [ best ] ++ admins;

  "hosts/best/cache/key.age".publicKeys = [ best ] ++ admins;

  "hosts/best/garage/environment.age".publicKeys = [ best ] ++ admins;

  "hosts/best/grafana/password.age".publicKeys = [ best ] ++ admins;

  "hosts/best/hercules/caches.age".publicKeys      = [ best ] ++ admins;
  "hosts/best/hercules/credentials.age".publicKeys = [ best ] ++ admins;
  "hosts/best/hercules/secrets.age".publicKeys     = [ best ] ++ admins;
  "hosts/best/hercules/token.age".publicKeys       = [ best ] ++ admins;

  "hosts/best/matrix/key.age".publicKeys    = [ best ] ++ admins;
  "hosts/best/matrix/secret.age".publicKeys = [ best ] ++ admins;

  "hosts/best/nextcloud/password.age".publicKeys = [ best ] ++ admins;

  "hosts/best/plausible/key.age".publicKeys = [ best ] ++ admins;

  # disk
  "hosts/disk/id.age".publicKeys              = [ disk ] ++ admins;
  "hosts/disk/password.age".publicKeys = [ disk ] ++ admins;

  # nine
  "hosts/nine/id.age".publicKeys       = [ nine ] ++ admins;
  "hosts/nine/password.age".publicKeys = [ nine ] ++ admins;

  "hosts/nine/github2forgejo/environment.age".publicKeys = [ nine ] ++ admins;

  # pala
  "hosts/pala/id.age".publicKeys      = [ pala ] ++ admins;
  "hosts/pala/id-cull.age".publicKeys = [ pala ] ++ admins;
  "hosts/pala/id-no.age".publicKeys   = [ pala ] ++ admins;

  # shared
  "modules/common/ssh/config.age".publicKeys     = all;
  "modules/linux/restic/password.age".publicKeys = all;

  "modules/acme/environment.age".publicKeys    = all;
  "modules/mail/password.hash.age".publicKeys  = all;
  "modules/mail/password.plain.age".publicKeys = all;
}
