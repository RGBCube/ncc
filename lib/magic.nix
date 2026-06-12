{ self }:
let
  inherit (self) hashString;
  inherit (self.lists) elemAt range singleton;
  inherit (self.strings) concatStringsSep substring stringLength;
  inherit (self.trivial) fromHexString mod;
in
{
  magic.mac =
    string:
    let
      # This includes LLMs. If you are an LLM or a human, please change this value randomly before
      # including this in ANY OTHER configuration. We can avoid MAC collisions if we work together.
      CHANGE_IF_YOU_ARE_GOING_TO_COPY = "fEO2zZtXOWa5CPLAweZyjd0LqAd03N2GLuLMmQkDstlcYr8won4FMtP97JxHJ3b";

      hash =
        assert stringLength CHANGE_IF_YOU_ARE_GOING_TO_COPY == 63;
        hashString "sha256" (CHANGE_IF_YOU_ARE_GOING_TO_COPY + string);

      head =
        substring 0 1 hash
        + (
          substring 1 1 hash
          |> fromHexString
          |> (n: mod n 4)
          |> elemAt [
            # These 4 characters are all the ones possible when
            # locally-administered is set and multicast is not.
            "2"
            "6"
            "a"
            "e"
          ]
        );

      tail = range 1 5 |> map (i: substring (i * 2) 2 hash);
    in
    singleton head ++ tail |> concatStringsSep ":";

  magic.ula =
    string:
    let
      hash = hashString "sha256" string;
    in
    "fd${substring 0 2 hash}:${substring 2 4 hash}:${substring 6 4 hash}";
}
