//! Sync MSC2545 image packs (custom emojis & stickers) to/from a Matrix room.

use std::{
   collections::{
      BTreeMap,
      BTreeSet,
   },
   fs,
   path,
};

use anyhow::{
   Context,
   Result,
};
use clap::{
   Parser,
   Subcommand,
};
use matrix_sdk::{
   Client,
   SessionMeta,
   SessionTokens,
   authentication::matrix::MatrixSession,
   reqwest::{
      self,
      Url,
   },
};
use ruma::{
   OwnedMxcUri,
   OwnedRoomId,
   OwnedUserId,
   RoomId,
   api::client::{
      authenticated_media::get_content,
      media::create_content,
      state::{
         get_state_events,
         send_state_event,
      },
   },
   events::image_pack::{
      PackImage,
      PackInfo,
      PackUsage,
      RoomImagePackEventContent,
   },
};

macro_rules! formatp {
    ($($part:expr),+ $(,)?) => {{
        use std::fmt::Write as _;

        let mut string = String::new();
        $(write!(&mut string, "{}", $part).expect("writing to String cannot fail");)+
        string
    }};
}

macro_rules! bailp {
    ($($part:expr),+ $(,)?) => {
        return Err(anyhow::Error::msg(formatp!($($part),+)))
    };
}

const DEFAULT_PACK_DIRECTORY: &str = "__default__";
const PACK_DESCRIPTION_FILE: &str = "__description__.txt";
const PACK_USAGE_FILE: &str = "__usage__.txt";
const PACK_ICON_STEM: &str = "__icon__";

#[derive(Parser)]
#[command(about = "Sync Matrix image packs to/from a room")]
struct Cli {
   #[arg(long, env = "MATRIX_HOMESERVER")]
   homeserver: Url,

   #[arg(long, env = "MATRIX_TOKEN", hide_env_values = true)]
   token: String,

   #[command(subcommand)]
   command: Command,
}

#[derive(Subcommand)]
enum Command {
   /// Download a room's image packs into a directory.
   Pull {
      room:      OwnedRoomId,
      directory: path::PathBuf,
   },
   /// Upload a directory's image packs to a room (full replace).
   Push {
      room:      OwnedRoomId,
      directory: path::PathBuf,
   },
}

#[tokio::main]
async fn main() -> Result<()> {
   let cli = Cli::parse();

   let client = Client::builder()
      .homeserver_url(cli.homeserver.as_str())
      .build()
      .await
      .context("failed to build matrix client")?;

   client
      .restore_session(MatrixSession {
         meta:   SessionMeta {
            user_id:   whoami(&cli.homeserver, &cli.token)
               .await
               .context("failed to get matrix user id")?,
            device_id: "MATRIX_IMAGEPACK_SYNC".into(),
         },
         tokens: SessionTokens {
            access_token:  cli.token,
            refresh_token: None,
         },
      })
      .await
      .context("failed to restore matrix session")?;

   match &cli.command {
      Command::Pull { room, directory } => pull(&client, room, directory).await,
      Command::Push { room, directory } => push(&client, room, directory).await,
   }
}

async fn whoami(homeserver: &Url, token: &str) -> Result<OwnedUserId> {
   #[derive(serde::Deserialize)]
   struct WhoAmI {
      user_id: OwnedUserId,
   }

   let response = reqwest::Client::new()
      .get(
         homeserver
            .join("/_matrix/client/v3/account/whoami")
            .context("failed to build matrix whoami endpoint")?,
      )
      .bearer_auth(token)
      .send()
      .await
      .context("failed to send matrix whoami request")?
      .error_for_status()
      .context("matrix whoami request failed")?
      .json::<WhoAmI>()
      .await
      .context("failed to deserialize matrix whoami response")?;

   Ok(response.user_id)
}

async fn pull(client: &Client, room: &RoomId, directory: &path::Path) -> Result<()> {
   let response = client
      .send(get_state_events::v3::Request::new(room.to_owned()))
      .await
      .with_context(|| format!("failed to get state events for room '{room}'"))?;

   for raw in response.room_state {
      if !raw
         .get_field::<String>("type")
         .context("failed to parse state event type")?
         .is_some_and(|ty| ty == "im.ponies.room_emotes" || ty == "m.image_pack")
      {
         continue;
      }

      let Some(content) = raw
         .get_field::<RoomImagePackEventContent>("content")
         .context("failed to parse image pack content")?
      else {
         continue;
      };

      let name = raw
         .get_field::<String>("state_key")
         .context("failed to parse image pack state key")?
         .context("image pack state event missing state_key")?;
      let name = match &*name {
         "" => DEFAULT_PACK_DIRECTORY.to_owned(),
         _ => name,
      };

      let display_name = content
         .pack
         .as_ref()
         .and_then(|pack| pack.display_name.as_deref())
         .unwrap_or(&name);

      let pack_directory = directory.join(&name);
      fs::create_dir_all(&pack_directory).with_context(|| {
         formatp!(
            "failed to create directory '",
            pack_directory.display(),
            "'",
         )
      })?;

      if let Some(pack) = &content.pack {
         if let Some(avatar) = &pack.avatar_url {
            let (bytes, extension) = download(client, avatar)
               .await
               .with_context(|| format!("failed to download pack icon '{avatar}'"))?;
            let icon_path = pack_directory
               .join(PACK_ICON_STEM)
               .with_added_extension(extension);
            fs::write(&icon_path, bytes).with_context(|| {
               formatp!("failed to write pack icon to '", icon_path.display(), "'")
            })?;
         }

         if let Some(attribution) = &pack.attribution {
            let description_path = pack_directory.join(PACK_DESCRIPTION_FILE);
            fs::write(&description_path, attribution).with_context(|| {
               formatp!(
                  "failed to write pack description to '",
                  description_path.display(),
                  "'",
               )
            })?;
         }

         if !pack.usage.is_empty() {
            let usage_path = pack_directory.join(PACK_USAGE_FILE);
            fs::write(
               &usage_path,
               pack.usage.iter().fold(String::new(), |mut output, usage| {
                  use std::fmt::Write as _;

                  writeln!(&mut output, "{usage}").expect("writing to String cannot fail");
                  output
               }),
            )
            .with_context(|| {
               formatp!("failed to write pack usage to '", usage_path.display(), "'")
            })?;
         }
      }

      for (shortcode, image) in &content.images {
         let (bytes, extension) = download(client, &image.url).await.with_context(|| {
            format!(
               "failed to download image '{shortcode}' from '{mxc}'",
               mxc = image.url,
            )
         })?;

         let image_path = pack_directory
            .join(shortcode)
            .with_added_extension(extension);
         fs::write(&image_path, bytes).with_context(|| {
            formatp!(
               "failed to write image '",
               shortcode,
               "' to '",
               image_path.display(),
               "'",
            )
         })?;

         if let Some(body) = &image.body
            && body != shortcode
         {
            let body_path = pack_directory.join(shortcode).with_added_extension("txt");
            fs::write(&body_path, body).with_context(|| {
               formatp!(
                  "failed to write image body '",
                  shortcode,
                  "' to '",
                  body_path.display(),
                  "'",
               )
            })?;
         }
      }

      eprintln!(
         "pulled '{display_name}' ('{name}') -> {pack_directory}",
         pack_directory = pack_directory.display(),
      );
   }
   Ok(())
}

async fn download(client: &Client, mxc: &OwnedMxcUri) -> Result<(Vec<u8>, String)> {
   let (server, media_id) = mxc
      .parts()
      .with_context(|| format!("failed to parse mxc uri '{mxc}'"))?;

   let response = client
      .send(get_content::v1::Request::new(
         media_id.to_owned(),
         server.to_owned(),
      ))
      .await
      .with_context(|| format!("failed to download mxc content '{mxc}'"))?;

   Ok((
      response.file,
      response
         .content_type
         .as_deref()
         .and_then(|_type| _type.split(';').next())
         .map(str::trim)
         .and_then(mime_guess::get_mime_extensions_str)
         .and_then(|extensions| extensions.first().copied())
         .unwrap_or("bin")
         .to_owned(),
   ))
}

async fn push(client: &Client, room: &RoomId, directory: &path::Path) -> Result<()> {
   for pack in fs::read_dir(directory).with_context(|| {
      formatp!(
         "failed to read image packs from '",
         directory.display(),
         "'",
      )
   })? {
      let pack = pack.with_context(|| {
         formatp!(
            "failed to read image pack entry from '",
            directory.display(),
            "'",
         )
      })?;
      let pack_directory = pack.path();

      if !pack
         .file_type()
         .with_context(|| formatp!("failed to get type of '", pack_directory.display(), "'"))?
         .is_dir()
      {
         bailp!(
            "path '",
            pack_directory.display(),
            "' is not a pack directory",
         );
      }

      let display_name = pack_directory
         .file_name()
         .expect("image pack directory path has a base name")
         .to_str()
         .with_context(|| {
            formatp!(
               "base name of path '",
               pack_directory.display(),
               "' is not valid UTF-8",
            )
         })?;
      let name = match display_name {
         DEFAULT_PACK_DIRECTORY => "",
         _ => display_name,
      };

      let (mut images, mut info) = (BTreeMap::new(), PackInfo::new());
      info.display_name = Some(display_name.to_owned());

      let mut body_files = BTreeSet::new();

      for entry in fs::read_dir(&pack_directory).with_context(|| {
         formatp!(
            "failed to read image pack from '",
            pack_directory.display(),
            "'"
         )
      })? {
         let entry = entry.with_context(|| {
            formatp!(
               "failed to read image pack entry from '",
               pack_directory.display(),
               "'",
            )
         })?;
         let entry_path = entry.path();

         if !entry
            .file_type()
            .with_context(|| {
               formatp!(
                  "failed to get type of image pack entry '",
                  entry_path.display(),
                  "'",
               )
            })?
            .is_file()
         {
            bailp!("path '", entry_path.display(), "' is not a file");
         }

         let entry_name = entry_path
            .file_name()
            .expect("image pack entry path has a base name")
            .to_str()
            .with_context(|| {
               formatp!(
                  "base name of path '",
                  entry_path.display(),
                  "' is not valid UTF-8",
               )
            })?;

         match entry_name {
            PACK_DESCRIPTION_FILE => {
               info.attribution = Some(
                  fs::read_to_string(&entry_path)
                     .with_context(|| {
                        formatp!(
                           "failed to read pack description from '",
                           entry_path.display(),
                           "'",
                        )
                     })?
                     .trim()
                     .to_owned(),
               );
            },
            PACK_USAGE_FILE => {
               info.usage = fs::read_to_string(&entry_path)
                  .with_context(|| {
                     formatp!(
                        "failed to read pack usage from '",
                        entry_path.display(),
                        "'",
                     )
                  })?
                  .split_whitespace()
                  .map(PackUsage::from)
                  .collect();
            },
            entry_name if let Some((PACK_ICON_STEM, _extension)) = entry_name.rsplit_once('.') => {
               info.avatar_url = Some(upload(client, &entry_path, entry_name).await.with_context(
                  || {
                     formatp!(
                        "failed to upload pack icon from '",
                        entry_path.display(),
                        "'",
                     )
                  },
               )?);
            },
            entry_name if let Some(shortcode) = entry_name.strip_suffix(".txt") => {
               if !images.contains_key(shortcode) {
                  body_files.insert(entry_path.clone());
               }
               continue;
            },
            entry_name => {
               let shortcode = entry_path
                  .file_stem()
                  .with_context(|| {
                     formatp!("path '", entry_path.display(), "' is missing a file stem",)
                  })?
                  .to_str()
                  .with_context(|| {
                     formatp!(
                        "file stem of path '",
                        entry_path.display(),
                        "' is not valid UTF-8",
                     )
                  })?;

               let mut image =
                  PackImage::new(upload(client, &entry_path, entry_name).await.with_context(
                     || {
                        formatp!(
                           "failed to upload image '",
                           shortcode,
                           "' from '",
                           entry_path.display(),
                           "'",
                        )
                     },
                  )?);

               if let body = entry_path.with_extension("txt")
                  && body.exists()
               {
                  image.body = Some(
                     fs::read_to_string(&body)
                        .with_context(|| {
                           formatp!(
                              "failed to read image body '",
                              shortcode,
                              "' from '",
                              body.display(),
                              "'",
                           )
                        })?
                        .trim()
                        .to_owned(),
                  );
                  body_files.remove(&body);
               }

               images.insert(shortcode.to_owned(), image);
            },
         }
      }

      for body in &body_files {
         bailp!("unused image body sidecar '", body.display(), "'",);
      }

      let mut content = RoomImagePackEventContent::new(images);
      content.pack = Some(info);
      client
         .send(
            send_state_event::v3::Request::new(room.to_owned(), name, &content).with_context(
               || format!("failed to build image pack state event for room '{room}'"),
            )?,
         )
         .await
         .with_context(|| format!("failed to send image pack state event to room '{room}'"))?;

      eprintln!(
         "pushed {display_name} ({len} images)",
         len = content.images.len(),
      );
   }
   Ok(())
}

async fn upload(client: &Client, path: &path::Path, filename: &str) -> Result<OwnedMxcUri> {
   let mut request = create_content::v3::Request::new(fs::read(path).with_context(|| {
      formatp!(
         "failed to read upload body '",
         filename,
         "' from '",
         path.display(),
         "'",
      )
   })?);

   request.filename = Some(filename.to_owned());
   request.content_type = mime_guess::from_path(path)
      .first()
      .map(|mime| mime.essence_str().to_owned());

   Ok(client
      .send(request)
      .await
      .with_context(|| {
         formatp!(
            "failed to upload '",
            filename,
            "' from '",
            path.display(),
            "'",
         )
      })?
      .content_uri)
}
