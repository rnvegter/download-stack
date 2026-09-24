# Download stack

SABnzbd, Radarr, Sonarr and Prowlarr in Docker, with Uptime Kuma and Dozzle for
monitoring, configured from a single `.env` file.

| App         | Role                                                  | Default URL           |
|-------------|-------------------------------------------------------|-----------------------|
| SABnzbd     | Usenet downloader                                     | http://localhost:8080 |
| Radarr      | Finds and manages movies                              | http://localhost:7878 |
| Sonarr      | Finds and manages TV series                           | http://localhost:8989 |
| Prowlarr    | Manages indexers once and syncs them to Radarr/Sonarr | http://localhost:9696 |
| Uptime Kuma | Checks that every app is up and alerts you if not     | http://localhost:3001 |
| Dozzle      | Live logs of all containers in the browser            | http://localhost:8888 |

SABnzbd, Radarr, Sonarr and Prowlarr use [linuxserver.io](https://www.linuxserver.io/)
images. Uptime Kuma (`louislam/uptime-kuma`) and Dozzle (`amir20/dozzle`) use
their official images.

## Files

```
.
├── .env.example         # template with all settings, committed to git
├── .env                 # your settings (created by setup.sh, not committed)
├── docker-compose.yml   # service definitions, reads everything from .env
├── setup.sh             # install, start and update the stack
├── config/              # app settings and databases (one folder per app)
└── data/
    ├── usenet/          # SABnzbd downloads (incomplete/, complete/)
    └── media/           # your library (movies/, tv/)
```

SABnzbd, Radarr and Sonarr mount the same `data/` folder as `/data`. Because
downloads and library are on one mount, Radarr and Sonarr can move finished
downloads instantly (hardlink/rename) instead of copying them.

`.env` and the `config/` and `data/` folders are in `.gitignore`: they hold
machine-specific settings, API keys and databases.

## Requirements

- Docker with Compose v2 (`docker compose`). On macOS, install one of:
  - [OrbStack](https://orbstack.dev/) (lightweight, recommended on Mac)
  - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- A Usenet provider account and at least one indexer.

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
   - creates the `config/` and `data/` folders
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

Configure the apps in this order. Each step needs an API key from the one
before it. You find the API key in every app under **Settings → General**
(SABnzbd: **Config → General**).

> Use service names (`sabnzbd`, `radarr`, `sonarr`, `prowlarr`), not
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
4. Copy Radarr's API key from **Settings → General**.

### 3. Sonarr

Same as Radarr, with:
- URL: http://localhost:8989
- Root folder: `/data/media/tv`
- SABnzbd category: `tv`

Copy Sonarr's API key as well.

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

## Monitoring

### Uptime Kuma

1. Open http://localhost:3001 and create an admin account.
2. **Add New Monitor** for each app. Use type **HTTP(s)** and the service name,
   so the check runs inside the Docker network:

   | Name     | URL                    |
   |----------|------------------------|
   | SABnzbd  | `http://sabnzbd:8080`  |
   | Radarr   | `http://radarr:7878/ping` |
   | Sonarr   | `http://sonarr:8989/ping` |
   | Prowlarr | `http://prowlarr:9696/ping` |

   Radarr, Sonarr and Prowlarr have a `/ping` endpoint that works without
   logging in.
3. Optional, to watch the containers themselves: **Settings → Docker Hosts →
   Setup Docker Host**, connection type **Socket**, path
   `/var/run/docker.sock`. Then add monitors of type **Docker Container**.
4. **Settings → Notifications**: add where alerts should go (Telegram,
   Pushover, ntfy, email, ...) and enable it on your monitors.
5. Optional: **Status Pages** gives you one overview page for the whole stack.

### Dozzle

Open http://localhost:8888. All containers and their live logs are listed
there, with search. There's nothing to configure.

> Dozzle has no login by default, and both Dozzle and Uptime Kuma can read the
> Docker socket. Keep them on your home network only. Don't forward their
> ports on your router.

## Updating the stack

There are two kinds of updates: new versions of the **app images**, and changes
to **this repository** (new services, compose changes).

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
`.env` without touching the values you already have.

### Pin or roll back a version

Every image has a tag in `.env` (`SABNZBD_TAG`, `RADARR_TAG`, `SONARR_TAG`,
`PROWLARR_TAG`, `UPTIME_KUMA_TAG`, `DOZZLE_TAG`). Uptime Kuma is set to `2`,
which follows version 2 updates but won't jump to a future major version. To stay on a known-good version, set the tag to a
specific release instead of `latest`, then run `docker compose up -d`:

```
RADARR_TAG=5.14.0
```

Find available tags on the image's page on
[linuxserver.io](https://docs.linuxserver.io/) or Docker Hub
([uptime-kuma](https://hub.docker.com/r/louislam/uptime-kuma/tags),
[dozzle](https://hub.docker.com/r/amir20/dozzle/tags)).

### Back up before a big update

Stop the stack and copy the `config/` folder. That's everything needed to
restore your settings:

```bash
docker compose down
tar czf "config-backup-$(date +%F).tar.gz" config
docker compose up -d
```

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
- **Port already in use:** change the `*_PORT` value in `.env`, then run
  `docker compose up -d`.
- **Radarr/Sonarr copy files instead of moving them:** downloads and media must
  both live under `DATA_ROOT` on the same filesystem.
- **Apps can't reach each other:** use the service name (`radarr`, not
  `localhost`) and the container port (the right-hand side in
  `docker-compose.yml`), not the host port from `.env`.
