# roba: back up your research to the lab server, and say so out loud

roba keeps a second copy of your work on the lab server and never removes one. It exists
because one automated job, or one wrong command, can delete a whole home directory: the code,
the recordings, and every commit that was never pushed.

## What it does

- **git**: pushes every branch and tag of the repositories you list. It can run by itself every hour.
- **data**: datasets, weights and runs are backed up when you say so, with one command, into a
  dated snapshot. Files that did not change are hard links, so they cost no extra space.
- **loud**: the hourly timer never uploads silently. Each run shows a desktop notification with a
  sound, and it reminds you about any data folder that changed since its last backup.
- **cannot delete**: roba pushes with its own SSH key. On the server that key can run only
  `server/roba-serve`, which:
  - accepts git pushes but refuses deleting a branch and refuses rewriting history;
  - accepts data through `rrsync -no-del`.
  A mistake on your machine can add to the backups, but it cannot remove them. When you rewrite a
  branch, the new version is kept next to the old one, under `refs/roba-diverged/<time>/`.

## Use it

```bash
./roba init                                   # config, list, and a dedicated key (~/.ssh/roba_ed25519)
./roba install-server                         # once, with your normal login: puts roba-serve on the server
./roba add ~/PROJECTS/my-repo                 # git is detected; anything else is data
./roba add ~/data/recordings private          # has people in it: lab server only, never Hugging Face
./roba git                                    # push all git entries now
./roba data ~/runs/exp42                      # back up one folder now; it is added to the list
./roba status                                 # what is backed up, and what is not
./roba install-timer                          # every hour: push git and remind about data
./roba hf my_dataset                          # upload a data entry marked hf=user/repo, and nothing else
```

The list is `~/.config/roba/backup.list`, one line per entry, and you can edit it by hand:

```
git   ~/PROJECTS/my-robot
data  ~/datasets/my_dataset       hf=you/my_dataset
data  ~/experiments/with-people   private
```

On the server everything lives under `~/backups`, which roba keeps at mode 700 so other accounts on the server cannot read it:
- `git/<name>.git` holds the repositories.
- `data/<name>/<YYYYmmdd-HHMMSS>/` holds the snapshots.

## For other lab members

Copy this folder, run `roba init`, and set `host` in `~/.config/roba/config` to your own login on
the lab server: roba refuses to reach a server until you do. Then run `roba install-server` with
that account, and add your folders. You do not have to install the timer: run
`roba git` and `roba data <path>` whenever you finish something.

## Tests

`tests/test_serve.sh` proves the server-side promises without a server: it checks that the tool
refuses what is not a roba command, refuses a deletion, refuses a rewrite, and keeps the old history.
