let
  package =
    {
      autoPatchelfHook,
      cairo,
      copyDesktopItems,
      curl,
      dbus,
      fontconfig,
      freetype,
      glib,
      gtk3,
      lib,
      libGL,
      libdrm,
      libkrb5,
      libsecret,
      libunwind,
      libxkbcommon,
      makeDesktopItem,
      makeWrapper,
      openssl,
      python313,
      qt6,
      stdenv,
      writePython3Bin,
      xorg,
      zlib,
    }:
    let
      python = python313.withPackages (pyPkgs: [ pyPkgs.rpyc ]);

      rape =
        writePython3Bin "rape"
          {
            flakeIgnore = [
              "E501" # Line too long.
            ];
          }
          # py
          ''
            import hashlib
            import json
            import sys
            from datetime import datetime, timezone
            from os import path, urandom

            # Impurity in MY Nix derivation?
            # It's more likely than you think!
            now = datetime.now(timezone.utc)
            user = "ilfak@hex-rays.com"

            license = {
              "payload": {
                "name": user,
                "email": user,
                "licenses": [
                  {
                    "id": "96-2137-ACAB-99",
                    "owner": user,
                    "product_id": "IDAPRO",
                    "edition_id": "ida-pro",
                    "description": "IDA Pro",
                    "start_date": now.strftime("%Y-%m-%d"),
                    "end_date": now.replace(year=now.year + 3).strftime("%Y-%m-%d"),
                    "issued_on": now.strftime("%Y-%m-%d %H:%M:%S"),
                    "license_type": "named",
                    "seats": 999,
                    "add_ons": [
                      {
                        "id": f"97-1337-DEAD-{count:02}",
                        "code": addon,
                        "owner": license["payload"]["licenses"][0]["id"],
                        "start_date": now.strftime("%Y-%m-%d"),
                        "end_date": now.replace(year=now.year + 10).strftime("%Y-%m-%d"),
                      } for count, addon in enumerate([
                        "HEXX86",
                        "HEXX64",
                        "HEXARM",
                        "HEXARM64",
                        "HEXMIPS",
                        "HEXMIPS64",
                        "HEXPPC",
                        "HEXPPC64",
                        "HEXRV",
                        "HEXRV64",
                        "HEXARC",
                        "HEXARC64",
                        "TEAMS",
                        "LUMINA",
                      ])
                    ],
                  }
                ],
              },
              "header": {"version": 1},
            }

            def json_stringify_alphabetical(obj) -> str:
              return json.dumps(obj, sort_keys=True, separators=(",", ":"))

            def buf_to_bigint(buf: bytes) -> int:
              return int.from_bytes(buf, byteorder="little")

            def bigint_to_buf(i):
              return i.to_bytes((i.bit_length() + 7) // 8, byteorder="little")

            pub_modulus_hexrays: int = buf_to_bigint(bytes.fromhex(
              "edfd425cf978546e8911225884436c57140525650bcf6ebfe80edbc5fb1de68f4c66c29cb22eb668788afcb0abbb718044584b810f8970cddf227385f75d5dddd91d4f18937a08aa83b28c49d12dc92e7505bb38809e91bd0fbd2f2e6ab1d2e33c0c55d5bddd478ee8bf845fcef3c82b9d2929ecb71f4d1b3db96e3a8e7aaf93"
            ))
            pub_modulus_patched: int = buf_to_bigint(bytes.fromhex(
              "edfd42cbf978546e8911225884436c57140525650bcf6ebfe80edbc5fb1de68f4c66c29cb22eb668788afcb0abbb718044584b810f8970cddf227385f75d5dddd91d4f18937a08aa83b28c49d12dc92e7505bb38809e91bd0fbd2f2e6ab1d2e33c0c55d5bddd478ee8bf845fcef3c82b9d2929ecb71f4d1b3db96e3a8e7aaf93"
            ))
            private_key: int = buf_to_bigint(bytes.fromhex(
              "77c86abbb7f3bb134436797b68ff47beb1a5457816608dbfb72641814dd464dd640d711d5732d3017a1c4e63d835822f00a4eab619a2c4791cf33f9f57f9c2ae4d9eed9981e79ac9b8f8a411f68f25b9f0c05d04d11e22a3a0d8d4672b56a61f1532282ff4e4e74759e832b70e98b9d102d07e9fb9ba8d15810b144970029874"
            ))

            def decrypt(message) -> bytes:
              bdecrypted = pow(buf_to_bigint(message), exponent, pub_modulus_patched)
              decrypted = bigint_to_buf(bdecrypted)
              return decrypted[::-1]

            def encrypt(message) -> bytes:
              encrypted = pow(buf_to_bigint(message[::-1]), private_key, pub_modulus_patched)
              encrypted = bigint_to_buf(encrypted)
              return encrypted

            exponent = 0x13

            def sign_hexlic(payload: dict) -> str:
              data = json_stringify_alphabetical({"payload": payload})
              buffer = bytearray(128)
              seed = urandom(32)
              for i in range(32):
                buffer[1 + i] = seed[i]
              sha256 = hashlib.sha256()
              sha256.update(data.encode())
              digest = sha256.digest()
              for i in range(32):
                buffer[33 + i] = digest[i]
                continue
              encrypted = encrypt(buffer)
              return encrypted.hex().upper()

            for index, filename in enumerate(sys.argv):
              if index == 0:
                assert filename == "--save-license-under"
                continue
              if index == 1:
                filename = path.join(filename, "idapro_" + license["payload"]["licenses"][0]["id"] + ".hexlic")

                license["signature"] = sign_hexlic(license["payload"])
                message = bytes.fromhex(license["signature"])
                serialized = json.dumps(license, indent=2)

                with open(filename, mode="w", encoding="utf-8", newline="\n") as file:
                  file.write(serialized)

                print(f"saved new license to {path.abspath(filename)}!")
                continue

              assert path.exists(filename), f"{filename} does not exist"

              NIG = bytes.fromhex("EDFD425CF978")
              NAG = bytes.fromhex("EDFD42CBF978")

              with open(filename, mode="rwb") as file:
                data = file.read()

                if data.find(NAG) != -1:
                  print(f"{filename} looks to be already patched :)")
                  continue
                elif data.find(NIG) == -1:
                  print(f"{filename} doesn't contain the original modulus ??")
                  continue
                else:
                  file.write(data.replace(NIG, NAG))
                  print(f"file {filename} patched!")

            assert index == 0 || index >= 1, "i need an argument for --save-license-under nigga"
          '';
    in
    stdenv.mkDerivation (finalAttrs: {
      pname = "ida-pro";
      version = "9.2.0.250908";

      src = builtins.fetchurl {
        url = "file://${toString ./.}/modules/linux/ida-pro_91_x64linux.run";
        sha256 = "1qpr02bkq6yhd3fpzgnbzmnb4mhk1l0h3sp3m69zc3ispqi81w4g";
      };

      desktopItem = makeDesktopItem {
        name = "IDA Pro";
        exec = "${finalAttrs.outPath}/bin/ida-pro";
        icon = ./ida-pro.png;
        comment = finalAttrs.meta.description;
        desktopName = "IDA Pro";
        genericName = "Interactive Disassembler";
        categories = [ "Development" ];
        startupWMClass = "IDA";
      };
      desktopItems = [ finalAttrs.desktopItem ];

      nativeBuildInputs = [
        makeWrapper
        copyDesktopItems
        autoPatchelfHook
        rape
        qt6.wrapQtAppsHook
      ];

      # We just get a runfile in $src, so no need to unpack it.
      dontUnpack = true;

      # Add everything to the RPATH, in case IDA decides to dlopen things.
      # This sucks ass nigga!
      buildInputs = finalAttrs.runtimeDependencies;
      runtimeDependencies = [
        cairo
        dbus
        fontconfig
        freetype
        glib
        gtk3
        libdrm
        libGL
        libkrb5
        libsecret
        qt6.qtbase
        qt6.qtwayland
        libunwind
        libxkbcommon
        libsecret
        openssl.out
        stdenv.cc.cc
        xorg.libICE
        xorg.libSM
        xorg.libX11
        xorg.libXau
        xorg.libxcb
        xorg.libXext
        xorg.libXi
        xorg.libXrender
        xorg.xcbutilimage
        xorg.xcbutilkeysyms
        xorg.xcbutilrenderutil
        xorg.xcbutilwm
        zlib
        curl.out
        python
      ];

      dontWrapQtApps = true;

      installPhase = ''
        runHook preInstall

        function print_debug_info() {
          if [ -f installbuilder_installer.log ]; then
            cat installbuilder_installer.log
          else
            echo "No debug information available."
          fi
        }

        trap print_debug_info EXIT

        mkdir --parents \
          $out/bin \
          $out/lib \
          $out/opt/.local/share/applications

        # IDA depends on quite some things extracted by the runfile, so first extract everything
        # into $out/opt, then remove the unnecessary files and directories.
        IDADIR=$out/opt
        # IDA doesn't always honor `--prefix`, so we need to hack and set $HOME here.
        HOME=$out/opt

        # Invoke the installer with the dynamic loader directly, avoiding the need
        # to copy it to fix permissions and patch the executable.
        $(cat $NIX_CC/nix-support/dynamic-linker) $src \
          --mode unattended --debuglevel 4 --prefix $IDADIR

        # Link the exported libraries to the output.
        for lib in $IDADIR/*.so $IDADIR/*.so.6; do
          ln --symbolic $lib $out/lib/$(basename $lib)
        done

        # Manually patch libraries that dlopen stuff.
        patchelf --add-needed libpython3.13.so $out/lib/libida.so
        patchelf --add-needed libcrypto.so $out/lib/libida.so
        patchelf --add-needed libsecret-1.so.0 $out/lib/libida.so

        # Some libraries come with the installer.
        addAutoPatchelfSearchPath $IDADIR

        # Link the binaries to the output.
        # Also, hack the PATH so that pythonForIDA is used over the system python.
        for bb in ida; do
          wrapProgram $IDADIR/$bb \
            --prefix IDADIR : $IDADIR \
            --prefix QT_PLUGIN_PATH : $IDADIR/plugins/platforms \
            --prefix PYTHONPATH : $out/bin/idalib/python \
            --prefix PATH : ${python}/bin:$IDADIR \
            --prefix LD_LIBRARY_PATH : $out/lib
          ln --symbolic $IDADIR/$bb $out/bin/$bb
        done

        runHook postInstall
      '';

      postInstall = ''
        rape \
          $out/opt/libida32.so \
          $out/opt/libida.so \
          --save-license-under $out/opt

        substituteInPlace $out/opt/cfg/hexrays.cfg \
          --replace "MAX_FUNCSIZE            = 64" "MAX_FUNCSIZE            = 1024"

        # Copy license to where IDA expects it
        cp *.hexlic $out/opt/ || true
      '';

      meta = {
        description = "The world's smartest and most feature-full disassembler";
        homepage = "https://hex-rays.com/ida-pro/";
        license = lib.licenses.unfree;
        mainProgram = "ida";
        platforms = [ "x86_64-linux" ]; # Right now, the installation script only supports Linux.
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };
    });
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.ida-pro = pkgs.callPackage package { };
    };
}
