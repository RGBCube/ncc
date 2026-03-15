{
  flake.darwinModules.libreoffice =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "libreoffice";
    };

  flake.homeModules.libreoffice =
    {
      osConfig,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs;
    in
    {
      xdg.mime-apps.default-applications = mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "libreoffice-writer.desktop") [
          "application/clarisworks"
          "application/docbook+xml"
          "application/macwriteii"
          "application/msword"
          "application/prs.plucker"
          "application/rtf"
          "application/vnd.apple.pages"
          "application/vnd.lotus-wordpro"
          "application/vnd.ms-word"
          "application/vnd.ms-word.document.macroEnabled.12"
          "application/vnd.ms-word.template.macroEnabled.12"
          "application/vnd.ms-works"
          "application/vnd.oasis.opendocument.text"
          "application/vnd.oasis.opendocument.text-flat-xml"
          "application/vnd.oasis.opendocument.text-master"
          "application/vnd.oasis.opendocument.text-master-template"
          "application/vnd.oasis.opendocument.text-template"
          "application/vnd.oasis.opendocument.text-web"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
          "application/vnd.palm"
          "application/vnd.stardivision.writer-global"
          "application/vnd.sun.xml.writer"
          "application/vnd.sun.xml.writer.global"
          "application/vnd.sun.xml.writer.template"
          "application/vnd.wordperfect"
          "application/wordperfect"
          "application/x-abiword"
          "application/x-aportisdoc"
          "application/x-doc"
          "application/x-extension-txt"
          "application/x-fictionbook+xml"
          "application/x-hwp"
          "application/x-iwork-pages-sffpages"
          "application/x-mswrite"
          "application/x-pocket-word"
          "application/x-sony-bbeb"
          "application/x-starwriter"
          "application/x-starwriter-global"
          "application/x-t602"
          "text/rtf"
        ]
        // flip genAttrs (const "libreoffice-calc.desktop") [
          "application/csv"
          "application/excel"
          "application/msexcel"
          "application/tab-separated-values"
          "application/vnd.apache.parquet"
          "application/vnd.apple.numbers"
          "application/vnd.lotus-1-2-3"
          "application/vnd.ms-excel"
          "application/vnd.ms-excel.sheet.binary.macroEnabled.12"
          "application/vnd.ms-excel.sheet.macroEnabled.12"
          "application/vnd.ms-excel.template.macroEnabled.12"
          "application/vnd.oasis.opendocument.chart"
          "application/vnd.oasis.opendocument.chart-template"
          "application/vnd.oasis.opendocument.spreadsheet"
          "application/vnd.oasis.opendocument.spreadsheet-flat-xml"
          "application/vnd.oasis.opendocument.spreadsheet-template"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
          "application/vnd.stardivision.calc"
          "application/vnd.stardivision.chart"
          "application/vnd.sun.xml.calc"
          "application/vnd.sun.xml.calc.template"
          "application/x-123"
          "application/x-dbase"
          "application/x-dbf"
          "application/x-dos_ms_excel"
          "application/x-excel"
          "application/x-gnumeric"
          "application/x-iwork-numbers-sffnumbers"
          "application/x-ms-excel"
          "application/x-msexcel"
          "application/x-quattropro"
          "application/x-starcalc"
          "application/x-starchart"
          "text/comma-separated-values"
          "text/csv"
          "text/spreadsheet"
          "text/tab-separated-values"
          "text/x-comma-separated-values"
          "text/x-csv"
        ]
        // flip genAttrs (const "libreoffice-impress.desktop") [
          "application/mspowerpoint"
          "application/vnd.apple.keynote"
          "application/vnd.ms-powerpoint"
          "application/vnd.ms-powerpoint.presentation.macroEnabled.12"
          "application/vnd.ms-powerpoint.slideshow.macroEnabled.12"
          "application/vnd.ms-powerpoint.template.macroEnabled.12"
          "application/vnd.oasis.opendocument.presentation"
          "application/vnd.oasis.opendocument.presentation-flat-xml"
          "application/vnd.oasis.opendocument.presentation-template"
          "application/vnd.openxmlformats-officedocument.presentationml.presentation"
          "application/vnd.openxmlformats-officedocument.presentationml.slide"
          "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
          "application/vnd.openxmlformats-officedocument.presentationml.template"
          "application/vnd.stardivision.impress"
          "application/vnd.sun.xml.impress"
          "application/vnd.sun.xml.impress.template"
          "application/x-iwork-keynote-sffkey"
          "application/x-starimpress"
        ]
        // flip genAttrs (const "libreoffice-draw.desktop") [
          "application/vnd.corel-draw"
          "application/vnd.ms-publisher"
          "application/vnd.oasis.opendocument.graphics"
          "application/vnd.oasis.opendocument.graphics-flat-xml"
          "application/vnd.oasis.opendocument.graphics-template"
          "application/vnd.quark.quarkxpress"
          "application/vnd.stardivision.draw"
          "application/vnd.sun.xml.draw"
          "application/vnd.sun.xml.draw.template"
          "application/vnd.visio"
          "application/x-pagemaker"
          "application/x-stardraw"
          "application/x-wpg"
          "image/x-emf"
          "image/x-freehand"
          "image/x-wmf"
        ];

      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.libreoffice
        pkgs.hunspellDicts.en_US
        pkgs.hunspellDicts.en_GB-ize
      ];
    };
}
