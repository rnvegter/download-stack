# Download stack

A Usenet media stack in Docker, configured from a single `.env` file: download
with SABnzbd, manage movies and series with Radarr and Sonarr, request with
Seerr, watch with Jellyfin, and monitor it all with Uptime Kuma and Dozzle.

| App         | Role                                                  | Default URL           |
|-------------|-------------------------------------------------------|-----------------------|
| SABnzbd     | Usenet downloader                                     | http://localhost:8080 |
| Radarr      | Finds and manages movies                              | http://localhost:7878 |
| Sonarr      | Finds and manages TV series                           | http://localhost:8989 |
| Prowlarr    | Manages indexers once and syncs them to Radarr/Sonarr | http://localhost:9696 |
| Bazarr      | Downloads subtitles for your movies and series        | http://localhost:6767 |
| Jellyfin    | Media server: watch your library on any device        | http://localhost:8096 |
| Seerr       | Request page for movies and series                    | http://localhost:5055 |
| Recyclarr   | Syncs TRaSH Guides quality settings (no web UI)       | –                     |
| Uptime Kuma | Checks that every app is up and alerts you if not     | http://localhost:3001 |
| Dozzle      | Live logs of all containers in the browser            | http://localhost:8888 |

SABnzbd, Radarr, Sonarr, Prowlarr, Bazarr and Jellyfin use
[linuxserver.io](https://www.linuxserver.io/) images. Seerr, Recyclarr, Uptime
Kuma and Dozzle use their official images.

## Files

```
.
├── .env.example           # template with all settings, committed to git
├── .env                   # your settings (created by setup.sh, not committed)
├── docker-compose.yml     # service definitions, reads everything from .env
├── setup.sh               # install, start and update the stack
├── backup.sh              # back up and restore config/
├── recyclarr/
│   └── recyclarr.yml      # Recyclarr template, copied to config/recyclarr/
├── config/                # app settings and databases (one folder per app)
├── backups/               # output of backup.sh
└── data/
    ├── usenet/            # SABnzbd downloads (incomplete/, complete/)
    └── media/             # your library (movies/, tv/)
```

SABnzbd, Radarr and Sonarr mount the same `data/` folder as `/data`. Because
downloads and library are on one mount, Radarr and Sonarr can move finished
downloads instantly (hardlink/rename) instead of copying them. Bazarr and
Jellyfin only see `data/media`, at the same path (`/data/media`), so paths
match across all apps.

`.env`, `config/`, `backups/` and `data/` are in `.gitignore`: they hold
machine-specific settings, API keys and databases.

## Requirements

- Docker with Compose v2 (`docker compose`). On macOS, install one of:
  - [OrbStack](https://orbstack.dev/) (lightweight, recommended on Mac)
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- A Usenet provider account and at least one indexer.

## Running on macOS

The scripts work with the bash version that ships with macOS. Check these
points before you start:

- **Run the scripts from Terminal.** Double-clicking `setup.sh` in Finder
  doesn't work well. If you downloaded the repository as a ZIP instead of with
  `git clone`, the scripts may have lost their executable flag. Run them as
  `bash setup.sh` and `bash backup.sh`, or fix it with
  `chmod +x setup.sh backup.sh`.
- **Docker socket (Docker Desktop only).** Uptime Kuma and Dozzle need
  `/var/run/docker.sock` to see your containers. OrbStack always provides it.
  In Docker Desktop, turn on **Settings → Advanced → Allow the default Docker
  socket to be used**.
- **Library on an external drive.** If `DATA_ROOT` points to `/Volumes/...`:
  - Docker Desktop needs that path under **Settings → Resources → File
    sharing**. OrbStack shares all folders by default.
  - Format the drive as **APFS**, not exFAT. exFAT doesn't support hardlinks,
    so Radarr and Sonarr copy every download instead of moving it instantly,
    which temporarily takes double the space.
- **Keep the Mac awake.** Downloads, imports and scheduled backups stop while
  the Mac sleeps. Turn on **System Settings → Battery (or Energy) → Prevent
  automatic sleeping when the display is off**, or use an app such as
  Amphetamine.
- **Start Docker at login.** Enable **Start at login** in OrbStack or Docker
  Desktop. The containers have `restart: unless-stopped`, so they come back
  on their own once Docker is running.
- **No GPU transcoding.** Jellyfin can't use the Mac's graphics chip from
  Docker. See the note under [Jellyfin](#7-jellyfin).

## Installation

1. **Install Docker** and start it. Check that it works:

   ```bash
   docker compose version
   ```

2. **Clone this repository:**

   ```bash
   git clone https://github.com/rnvegter/download-stack.git
   cd download-stack
   ```

3. **Run the setup script:**

   ```bash
   ./setup.sh
   ```

   The script:
   - checks that Docker and Compose are installed and running
   - creates `.env` from `.env.example` if it doesn't exist yet
   - offers to set `PUID`/`PGID` in `.env` to your current user
   - creates the `config/` and `data/` folders and the Recyclarr config
   - validates the compose file, pulls the images and starts the stack

   Use `./setup.sh --no-start` to prepare everything without starting. You can
   then edit `.env` first and start with `docker compose up -d`.

4. **Review `.env`** if you need other values, usually:
   - `TZ`: your timezone
   - `DATA_ROOT`: where downloads and media live. Point this at an external
     drive or NAS mount if your library isn't on this machine.
   - `*_PORT`: change a port if it's already in use

   After changing `.env`, apply it with `docker compose up -d`.

## First-time configuration

Configure the apps in this order. Later steps need API keys from earlier ones.
You find the API key in every app under **Settings → General** (SABnzbd:
**Config → General**).

> Use service names (`sabnzbd`, `radarr`, `sonarr`, `jellyfin`, ...), not
> `localhost`, when connecting apps to each other. Inside the Docker network,
> `localhost` means the container itself.

### 1. SABnzbd

1. Open http://localhost:8080 and follow the wizard. Enter your Usenet
   provider details.
2. **Config → Folders**:
   - Temporary Download Folder: `/data/usenet/incomplete`
   - Completed Download Folder: `/data/usenet/complete`
3. **Config → Categories**: add `movies` and `tv`.
4. **Config → General**: copy the **API Key**.

If the web UI says "access denied" or refuses the hostname, add `sabnzbd` to
**Config → Special → host_whitelist**.

### 2. Radarr

1. Open http://localhost:7878 and set up authentication.
2. **Settings → Media Management → Add Root Folder**: `/data/media/movies`
3. **Settings → Download Clients → + → SABnzbd**:
   - Host: `sabnzbd`, Port: `8080`
   - API Key: the key from SABnzbd
   - Category: `movies`
4. Copy Radarr's API key from **Settings → General** and paste it into `.env`
   as `RADARR_API_KEY` (Recyclarr uses it).

### 3. Sonarr

Same as Radarr, with:
- URL: http://localhost:8989
- Root folder: `/data/media/tv`
- SABnzbd category: `tv`
- API key goes into `.env` as `SONARR_API_KEY`

### 4. Prowlarr

Add indexers here instead of in Radarr and Sonarr. Prowlarr pushes them to both.

1. Open http://localhost:9696 and set up authentication.
2. **Indexers → Add Indexer**: add your Usenet indexer(s).
3. **Settings → Apps → + → Radarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: Radarr's key
4. **Settings → Apps → + → Sonarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: Sonarr's key
5. Click **Sync App Indexers**. The indexers now show up in Radarr and Sonarr
   under **Settings → Indexers**.

### 5. Recyclarr

Recyclarr applies the [TRaSH Guides](https://trash-guides.info/) quality
settings to Radarr and Sonarr, so they pick good releases without manual
tuning. It runs daily (`RECYCLARR_SCHEDULE` in `.env`) and has no web UI.

The default config in `config/recyclarr/recyclarr.yml` sets up:
- Radarr: the **HD Bluray + WEB** profile (720p/1080p)
- Sonarr: the **WEB-1080p** profile

1. Make sure `RADARR_API_KEY` and `SONARR_API_KEY` are filled in `.env`, then
   apply them:

   ```bash
   docker compose up -d recyclarr
   ```

2. Preview what Recyclarr will change, then run the first sync:

   ```bash
   docker compose run --rm recyclarr sync --preview
   docker compose run --rm recyclarr sync
   ```

3. In Radarr and Sonarr, the new profiles now appear under **Settings →
   Profiles**. Select them when you add movies and series (and in Seerr,
   below).

Want 4K or different profiles? Edit `config/recyclarr/recyclarr.yml`. See the
[Recyclarr docs](https://recyclarr.dev/wiki/) for the options.

### 6. Bazarr

1. Open http://localhost:6767 and set up authentication under **Settings →
   General → Security**.
2. **Settings → Languages**: add the subtitle languages you want (for example
   Dutch and English), create a **Languages Profile** with them, and set it as
   the default for movies and series.
3. **Settings → Providers**: add subtitle sources, for example OpenSubtitles.com
   (free account) and Addic7ed.
4. **Settings → Radarr**: enable, host `radarr`, port `7878`, Radarr's API key.
5. **Settings → Sonarr**: enable, host `sonarr`, port `8989`, Sonarr's API key.

No path mappings are needed: Bazarr sees the library at `/data/media`, just
like Radarr and Sonarr.

### 7. Jellyfin

1. Open http://localhost:8096 and follow the wizard. Create an admin account.
2. **Add Media Library**:
   - Movies: content type **Movies**, folder `/data/media/movies`
   - Shows: content type **Shows**, folder `/data/media/tv`
3. Install the Jellyfin app on your TV, phone or tablet and connect to
   `http://<ip-of-this-mac>:8096`.

Optional: let Radarr and Sonarr refresh Jellyfin as soon as something is
imported. In Radarr/Sonarr go to **Settings → Connect → + → Emby / Jellyfin**,
host `jellyfin`, port `8096`, with an API key from Jellyfin (**Dashboard → API
Keys**).

> **On a Mac, Jellyfin transcodes with the CPU only.** Docker on macOS has no
> access to the GPU, so converting video for devices that can't play the
> original file is slow. Direct play (no transcoding) works fine. Use clients
> that support your files natively, such as the Jellyfin app on Apple TV,
> Android TV or Infuse.

### 8. Seerr

1. Open http://localhost:5055 and follow the wizard.
2. Choose **Jellyfin** as media server:
   - URL: `http://jellyfin:8096`
   - Sign in with your Jellyfin admin account
   - Select the libraries to sync
3. **Services → Radarr**:
   - Hostname: `radarr`, Port: `7878`, API Key: Radarr's key
   - Quality profile: the Recyclarr profile (**HD Bluray + WEB**)
   - Root folder: `/data/media/movies`
   - Tick **Default Server**
4. **Services → Sonarr**: same with hostname `sonarr`, port `8989`, the
   **WEB-1080p** profile and root folder `/data/media/tv`.

Requests made in Seerr now go straight to Radarr or Sonarr. Jellyfin users can
sign in to Seerr with their Jellyfin account.

## Monitoring

### Uptime Kuma

1. Open http://localhost:3001 and create an admin account.
2. **Add New Monitor** for each app. Use type **HTTP(s)** and the service name,
   so the check runs inside the Docker network:

   | Name     | URL                                |
   |----------|------------------------------------|
   | SABnzbd  | `http://sabnzbd:8080`              |
   | Radarr   | `http://radarr:7878/ping`          |
   | Sonarr   | `http://sonarr:8989/ping`          |
   | Prowlarr | `http://prowlarr:9696/ping`        |
   | Bazarr   | `http://bazarr:6767`               |
   | Jellyfin | `http://jellyfin:8096/health`      |
   | Seerr    | `http://seerr:5055/api/v1/status`  |

   These endpoints work without logging in.
3. Optional, to watch the containers themselves (including Recyclarr, which
   has no web page): **Settings → Docker Hosts → Setup Docker Host**,
   connection type **Socket**, path `/var/run/docker.sock`. Then add monitors
   of type **Docker Container**.
4. **Settings → Notifications**: add where alerts should go (Telegram,
   Pushover, ntfy, email, ...) and enable it on your monitors.
5. Optional: **Status Pages** gives you one overview page for the whole stack.

### Dozzle

Open http://localhost:8888. All containers and their live logs are listed
there, with search. There's nothing to configure.

> Dozzle has no login by default, and both Dozzle and Uptime Kuma can read the
> Docker socket. Keep them on your home network only. Don't forward their
> ports on your router.

## Backups

`backup.sh` saves the `config/` folder (all app settings and databases) to a
dated archive in `backups/`. Media and downloads in `data/` are **not** backed
up.

```bash
./backup.sh                  # make a backup
./backup.sh --list           # list backups
./backup.sh --restore FILE   # restore one
```

- **Consistent backups:** by default the script stops the stack for the few
  seconds the backup takes, then starts it again. This prevents half-written
  databases. Use `./backup.sh --no-stop` to skip that.
- **Small backups:** caches, logs, artwork and Jellyfin's metadata are
  skipped. The apps rebuild them automatically.
- **Retention:** only the newest `BACKUP_KEEP` backups (default 7) are kept.
  Older ones are deleted after each new backup.
- **Location:** set `BACKUP_DIR` in `.env`, for example to an external drive
  or a cloud-synced folder, so backups survive if this disk fails.
- **Restore:** asks for confirmation, stops the stack, moves your current
  `config/` aside to `config.before-restore-<date>`, unpacks the backup and
  starts the stack again. Delete the set-aside folder once everything works.

### Automatic daily backups (macOS)

Use `crontab -e` and add these two lines (adjust the path to this folder):

```
PATH=/usr/local/bin:/opt/homebrew/bin:/Users/YOUR_USER/.orbstack/bin:/usr/bin:/bin
0 4 * * * cd "/path/to/download-stack" && ./backup.sh >> backups/backup.log 2>&1
```

This runs a backup every night at 04:00, as long as the Mac is awake. The
`PATH` line is needed because cron doesn't know where `docker` is installed.
Check with `which docker` and make sure that folder is in the list.

## Updating the stack

There are two kinds of updates: new versions of the **app images**, and changes
to **this repository** (new services, compose changes). Make a backup first:

```bash
./backup.sh
```

### Update the apps (new image versions)

```bash
./setup.sh --update
```

This pulls the latest images, recreates only the containers whose image
changed, and removes old images. Your settings in `config/` and your files in
`data/` stay as they are.

The same by hand:

```bash
docker compose pull
docker compose up -d --remove-orphans
docker image prune -f
```

Update a single app:

```bash
docker compose pull radarr
docker compose up -d radarr
```

### Update this repository

```bash
git pull
./setup.sh --update
```

`setup.sh --update` also adds any new settings from `.env.example` to your
`.env` without touching the values you already have, and creates folders for
new services.

### Pin or roll back a version

Every image has a tag in `.env` (`SABNZBD_TAG`, `RADARR_TAG`, `SONARR_TAG`,
`PROWLARR_TAG`, `BAZARR_TAG`, `JELLYFIN_TAG`, `SEERR_TAG`, `RECYCLARR_TAG`,
`UPTIME_KUMA_TAG`, `DOZZLE_TAG`).

- Uptime Kuma is set to `2` and Recyclarr to `8`. They follow updates within
  that major version but won't jump to the next one, which may need config
  changes.
- To stay on a known-good version of any app, set its tag to a specific
  release instead of `latest`, then run `docker compose up -d`:

  ```
  RADARR_TAG=5.14.0
  ```

- If an update breaks something, set the tag back to the previous version and
  restore the backup you made before updating.

Find available tags on [linuxserver.io](https://docs.linuxserver.io/), or on
the image pages for [Seerr](https://github.com/seerr-team/seerr/pkgs/container/seerr),
[Recyclarr](https://github.com/recyclarr/recyclarr/pkgs/container/recyclarr),
[Uptime Kuma](https://hub.docker.com/r/louislam/uptime-kuma/tags) and
[Dozzle](https://hub.docker.com/r/amir20/dozzle/tags).

## Everyday commands

```bash
docker compose ps               # status
docker compose logs -f radarr   # follow logs of one service
docker compose restart          # restart everything
docker compose down             # stop and remove containers (config and data are kept)
```

## Troubleshooting

- **Permission errors on files:** make sure `PUID`/`PGID` in `.env` match the
  owner of `config/` and `data/` (`id -u`, `id -g`). Re-run `./setup.sh`.
- **Seerr won't start on Linux (permission denied on `/app/config`):** Seerr
  runs as UID 1000 and ignores `PUID`/`PGID`. Run
  `sudo chown -R 1000:1000 config/seerr`. Not needed on macOS.
- **Recyclarr logs "environment variable ... not set":** `RADARR_API_KEY` or
  `SONARR_API_KEY` is empty in `.env`. Fill it in and run
  `docker compose up -d recyclarr`.
- **Port already in use:** change the `*_PORT` value in `.env`, then run
  `docker compose up -d`.
- **Radarr/Sonarr copy files instead of moving them:** downloads and media must
  both live under `DATA_ROOT` on the same filesystem.
- **Apps can't reach each other:** use the service name (`radarr`, not
  `localhost`) and the container port (the right-hand side in
  `docker-compose.yml`), not the host port from `.env`.
- **Dozzle shows no containers, or Uptime Kuma can't connect to the Docker
  host:** the Docker socket isn't available. On Docker Desktop, enable **Allow
  the default Docker socket to be used** (see [Running on macOS](#running-on-macos)),
  then run `docker compose up -d --force-recreate dozzle uptime-kuma`.
- **"Mounts denied" or empty folders with `DATA_ROOT` on an external drive:**
  add the drive under Docker Desktop's **Settings → Resources → File sharing**.
- **Video stutters or buffers in Jellyfin:** it's probably transcoding on the
  CPU. Check **Dashboard → Activity**, and use a client that can play the file
  directly.
