//! Session daemon.

use std::{
   collections,
   env,
   process,
};

use anyhow::{
   Context as _,
   Result,
   bail,
   ensure,
};
use clap::Parser;
use zbus::{
   blocking::Connection,
   proxy::CacheProperties,
};

mod dbus {
   use zbus::zvariant;

   /// `ActiveState` of a unit.
   #[derive(Clone, Copy)]
   pub enum ActiveState {
      Active,
      Reloading,
      Inactive,
      Failed,
      Activating,
      Deactivating,
      Maintenance,
      Refreshing,
   }

   impl ActiveState {
      /// systemd's `UNIT_IS_INACTIVE_OR_FAILED`.
      pub fn is_inactive_or_failed(self) -> bool {
         matches!(self, Self::Inactive | Self::Failed)
      }
   }

   impl TryFrom<zvariant::OwnedValue> for ActiveState {
      type Error = zvariant::Error;

      fn try_from(value: zvariant::OwnedValue) -> Result<Self, Self::Error> {
         Ok(match value.downcast_ref::<&str>()? {
            "active" => Self::Active,
            "reloading" => Self::Reloading,
            "inactive" => Self::Inactive,
            "failed" => Self::Failed,
            "activating" => Self::Activating,
            "deactivating" => Self::Deactivating,
            "maintenance" => Self::Maintenance,
            "refreshing" => Self::Refreshing,

            state => {
               return Err(zvariant::Error::Message(format!(
                  "unknown ActiveState: {state}"
               )));
            },
         })
      }
   }

   #[zbus::proxy(
      default_service = "org.freedesktop.systemd1",
      default_path = "/org/freedesktop/systemd1",
      interface = "org.freedesktop.systemd1.Manager"
   )]
   pub trait SystemdManager {
      fn load_unit(&self, name: &str) -> zbus::Result<zvariant::OwnedObjectPath>;

      #[zbus(property)]
      fn environment(&self) -> zbus::Result<Vec<String>>;

      fn set_environment(&self, assignments: &[&str]) -> zbus::Result<()>;

      fn unset_environment(&self, names: &[&str]) -> zbus::Result<()>;

      #[zbus(signal)]
      fn job_removed(
         &self,
         id: u32,
         job: zvariant::OwnedObjectPath,
         unit: String,
         result: String,
      ) -> zbus::Result<()>;
   }

   #[zbus::proxy(
      default_service = "org.freedesktop.systemd1",
      interface = "org.freedesktop.systemd1.Unit"
   )]
   pub trait Unit {
      #[zbus(name = "Ref")]
      fn ref_(&self) -> zbus::Result<()>;

      fn reset_failed(&self) -> zbus::Result<()>;

      fn start(&self, mode: &str) -> zbus::Result<zvariant::OwnedObjectPath>;

      #[zbus(property)]
      fn active_state(&self) -> zbus::Result<ActiveState>;
   }

   #[zbus::proxy(
      default_service = "org.freedesktop.login1",
      default_path = "/org/freedesktop/login1",
      interface = "org.freedesktop.login1.Manager"
   )]
   pub trait Logind {
      fn get_seat(&self, id: &str) -> zbus::Result<zvariant::OwnedObjectPath>;

      #[zbus(property, name = "NAutoVTs")]
      fn n_auto_vts(&self) -> zbus::Result<u32>;

      #[zbus(signal)]
      fn secure_attention_key(
         &self,
         id: String,
         seat: zvariant::OwnedObjectPath,
      ) -> zbus::Result<()>;

      #[zbus(signal)]
      fn session_removed(&self, id: String, session: zvariant::OwnedObjectPath)
      -> zbus::Result<()>;
   }

   #[zbus::proxy(
      default_service = "org.freedesktop.login1",
      interface = "org.freedesktop.login1.Seat"
   )]
   pub trait Seat {
      #[zbus(property)]
      fn sessions(&self) -> zbus::Result<Vec<(String, zvariant::OwnedObjectPath)>>;

      #[zbus(property)]
      fn active_session(&self) -> zbus::Result<(String, zvariant::OwnedObjectPath)>;
   }

   #[zbus::proxy(
      default_service = "org.freedesktop.login1",
      interface = "org.freedesktop.login1.Session"
   )]
   pub trait Session {
      fn activate(&self) -> zbus::Result<()>;
   }
}

#[derive(Parser)]
#[command(multicall = true)]
enum Command {
   /// Session daemon.
   Sessiond {
      /// Unit template. Each SecureAttentionKey press starts one more
      /// instance.
      #[arg(long)]
      unit: String,

      /// Seat whose SecureAttentionKey and SessionRemoved to handle.
      #[arg(long)]
      seat: String,
   },

   /// Manager for the singleton session. Publishes the session ID in the
   /// systemd --user environment before running the user unit.
   ///
   /// After the user unit exits, removes any environment variables
   /// the unit set from systemd --user.
   SessionSingleton {
      /// User unit to run.
      #[arg(long)]
      unit: String,
   },

   /// Manager for instanced sessions. The unit template is instantiated
   /// with the session ID, and the unit is responsible for setting
   /// `XDG_SESSION_ID` to `%i`.
   SessionInstanced {
      /// User unit template. Instantiated with the session ID.
      #[arg(long)]
      unit: String,
   },
}

fn main() -> Result<process::ExitCode> {
   match Command::parse() {
      Command::Sessiond { unit, seat } => {
         let connection = Connection::system().context("connecting to the system bus")?;

         let (systemd, logind) = (
            dbus::SystemdManagerProxyBlocking::new(&connection)
               .context("creating the systemd proxy")?,
            dbus::LogindProxyBlocking::new(&connection).context("creating the logind proxy")?,
         );

         let seat = dbus::SeatProxyBlocking::builder(&connection)
            .path(logind.get_seat(&seat).context("looking up the seat")?)
            .context("addressing the seat")?
            .cache_properties(CacheProperties::No)
            .build()
            .context("creating the seat proxy")?;

         for message in logind
            .inner()
            .receive_all_signals()
            .context("subscribing to logind signals")?
         {
            match () {
               () if let Some(secure_attention_key) =
                  dbus::SecureAttentionKey::from_message(message.clone()) =>
               'handler: {
                  if &**secure_attention_key
                     .args()
                     .context("decoding SecureAttentionKey args")?
                     .seat()
                     != seat.inner().path()
                  {
                     break 'handler;
                  }

                  let limit = logind.n_auto_vts().context("reading the instance limit")?;

                  for instance in 1..=limit {
                     let name = instantiate(&unit, &instance.to_string())?;

                     let unit = dbus::UnitProxyBlocking::builder(&connection)
                        .path(systemd.load_unit(&name).context("loading an instance")?)
                        .context("addressing an instance")?
                        .cache_properties(CacheProperties::No)
                        .build()
                        .context("creating an instance proxy")?;

                     if !unit
                        .active_state()
                        .context("reading an instance state")?
                        .is_inactive_or_failed()
                     {
                        continue;
                     }

                     match start(&connection, &systemd, &name) {
                        Ok(_) => break 'handler,
                        Err(error) => eprintln!("failed to start {name}: {error:?}"),
                     }
                  }

                  eprintln!("started none of the {limit} instances");
               },

               () if let Some(_session_removed) =
                  dbus::SessionRemoved::from_message(message.clone()) =>
               'handler: {
                  let (active_session_id, active_session_path) = seat
                     .active_session()
                     .context("reading the active session")?;

                  let no_active_session =
                     active_session_id.is_empty() && &*active_session_path == "/";
                  if !no_active_session {
                     break 'handler;
                  }

                  for (session_id, session_path) in
                     seat.sessions().context("listing the sessions for seat")?
                  {
                     let session = dbus::SessionProxyBlocking::builder(&connection)
                        .path(session_path)
                        .context("addressing a session")?
                        .cache_properties(CacheProperties::No)
                        .build()
                        .context("creating a session proxy")?;

                     let Err(error) = session.activate() else {
                        break 'handler;
                     };

                     eprintln!("failed to activate session '{session_id}': {error:?}");
                  }

                  eprintln!("failed to activate any session lol good luck fam");
               },

               () => {},
            }
         }

         bail!("logind's signal stream ended")
      },

      Command::SessionSingleton { unit } => {
         let (session_id, connection) = (
            session_id()?,
            Connection::session().context("connecting to the user bus")?,
         );

         let usystemd = dbus::SystemdManagerProxyBlocking::builder(&connection)
            .cache_properties(CacheProperties::No)
            .build()
            .context("creating the manager proxy")?;

         let usystemd_environment = || {
            usystemd
               .environment()
               .context("reading the systemd --user environment")?
               .into_iter()
               .map(|assignment| {
                  assignment
                     .split_once('=')
                     .map(|(name, _value)| name.to_owned())
                     .with_context(|| {
                        format!(
                           "failed to get name of malformed environment assignment: {assignment}"
                        )
                     })
               })
               .collect::<Result<collections::BTreeSet<String>>>()
         };

         let environment_before = usystemd_environment()?;

         let unit = {
            // We are a root unit with PAMName, and our XDG_SESSION_ID
            // is set by root systemd for the scope of our unit, rather
            // than by systemd --user, so we have to propagate XDG_SESSION_ID
            // up to systemd --user for the compositor unit (a user unit) to see it.
            usystemd
               .set_environment(&[&format!("XDG_SESSION_ID={session_id}")])
               .context("setting XDG_SESSION_ID in systemd --user")?;

            start(&connection, &usystemd, &unit)?
         };

         let environment_after = usystemd_environment()?;

         let unit_result = {
            let status = wait(&unit);

            usystemd
               .unset_environment(
                  &environment_after
                     .difference(&environment_before)
                     .map(String::as_str)
                     .collect::<Vec<_>>(),
               )
               .context("clearing the manager environment")?;

            match status? {
               dbus::ActiveState::Failed => process::ExitCode::FAILURE,
               _ => process::ExitCode::SUCCESS,
            }
         };

         Ok(unit_result)
      },

      Command::SessionInstanced { unit } => {
         let (session_id, connection) = (
            session_id()?,
            Connection::session().context("connecting to the user bus")?,
         );

         let usystemd = dbus::SystemdManagerProxyBlocking::new(&connection)
            .context("creating the manager proxy")?;

         let status = wait(&start(
            &connection,
            &usystemd,
            &instantiate(&unit, &session_id)?,
         )?)?;

         Ok(match status {
            dbus::ActiveState::Failed => process::ExitCode::FAILURE,
            _ => process::ExitCode::SUCCESS,
         })
      },
   }
}

fn session_id() -> Result<String> {
   env::var("XDG_SESSION_ID")
      .context("failed to read XDG_SESSION_ID, not running inside a PAMName= unit?")
}

fn instantiate(template: &str, instance: &str) -> Result<String> {
   let (prefix, suffix) = template
      .split_once('@')
      .with_context(|| format!("unit '{template}' is not a template"))?;

   ensure!(
      suffix.starts_with('.'),
      "unit '{template}' is already instantiated"
   );

   Ok(format!("{prefix}@{instance}{suffix}"))
}

fn start(
   connection: &Connection,
   systemd: &dbus::SystemdManagerProxyBlocking<'_>,
   name: &str,
) -> Result<dbus::UnitProxyBlocking<'static>> {
   // Property caching is deliberately left on. `wait`'s property
   // iterator ends immediately without a cache.
   let unit = dbus::UnitProxyBlocking::builder(connection)
      .path(
         systemd
            .load_unit(name)
            .context("loading the session unit")?,
      )
      .context("addressing the session unit")?
      .build()
      .context("creating the unit proxy")?;

   // systemd emits PropertiesChanged only to either Subscribe'd clients
   // or clients who hold a Ref on the unit. `wait` depends on the signals.
   unit.ref_().context("referencing the session unit")?;

   unit.reset_failed().context("resetting the session unit")?;

   let jobs_removed = systemd
      .receive_job_removed()
      .context("listening for job removals")?;

   let job = unit
      .start("replace")
      .with_context(|| format!("starting {name}"))?;

   for signal in jobs_removed {
      let arguments = signal.args().context("decoding a job removal")?;
      if *arguments.job() != job {
         continue;
      }

      ensure!(
         arguments.result() == "done",
         "start job for {name} finished as '{state}'",
         state = arguments.result(),
      );

      return Ok(unit);
   }

   bail!("the manager's job stream ended")
}

fn wait(unit: &dbus::UnitProxyBlocking<'_>) -> Result<dbus::ActiveState> {
   let changes = unit.receive_active_state_changed();

   // Handle current state (the one before the iterator was created) first.
   let state = unit.active_state().context("reading the unit state")?;
   if state.is_inactive_or_failed() {
      return Ok(state);
   }

   for change in changes {
      let state = change.get().context("reading the unit state")?;
      if state.is_inactive_or_failed() {
         return Ok(state);
      }
   }

   bail!("the unit's property stream ended before the unit did")
}
